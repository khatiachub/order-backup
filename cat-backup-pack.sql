prompt PL/SQL Developer Export User Objects for user KHATIA@ORCL
prompt Created by xatia on Saturday, March 22, 2025
set define off
spool cat-backup-pack.log

prompt
prompt Creating package body PKG_TASKS_ORDERS
prompt ======================================
prompt
create or replace package body khatia.pkg_tasks_orders is

  PROCEDURE proc_add_order(p_client_id     NUMBER,
                           p_json_id       CLOB,
                           p_json_quantity CLOB,
                           p_order_date    DATE) AS
    v_order_id NUMBER;
  
  BEGIN
    INSERT INTO task_orders
      (client_id, order_date)
    VALUES
      (p_client_id, p_order_date)
    RETURNING id INTO v_order_id;
  
    FOR product_rec IN (
        SELECT jt_id.product_id, jt_qty.quantity
        FROM json_table(p_json_id, '$[*]' 
                        COLUMNS(
                            row_number FOR ORDINALITY, -- Generate row numbers for pairing
                            product_id NUMBER PATH '$'
                        )) jt_id
        JOIN json_table(p_json_quantity, '$[*]' 
                        COLUMNS(
                            row_number FOR ORDINALITY, -- Generate row numbers for pairing
                            quantity NUMBER PATH '$'
                        )) jt_qty
        ON jt_id.row_number = jt_qty.row_number -- Pair based on row numbers
    ) LOOP
      INSERT INTO task_order_details
        (order_id, product_id, quantity)
      VALUES
        (v_order_id, product_rec.product_id, product_rec.quantity);
    END LOOP;
  END proc_add_order;

  procedure proc_get_order(p_order_curs OUT SYS_REFCURSOR) as
  begin
    open p_order_curs for
      select o.id,
             c.name,
             o.quantity,
             JSON_ARRAYAGG(d.product_id) AS product_id
        from task_orders o
        left join clients c
          on o.client_id = c.id
       right join task_order_details d
          on d.order_id = o.id
       GROUP BY o.id, c.name, o.quantity;
  end proc_get_order;

  procedure proc_add_inventories(p_product_id  number,
                                 p_balance     number,
                                 p_create_date date) as
  begin
    insert into inventories
      (product_id, balance, create_date)
    values
      (p_product_id, p_balance, p_create_date);
  end proc_add_inventories;

  procedure proc_get_order_details(p_order_curs         OUT SYS_REFCURSOR,
                                   p_min_date_curs      OUT SYS_REFCURSOR,
                                   p_max_date_curs      OUT SYS_REFCURSOR,
                                   p_total_price_curs   OUT SYS_REFCURSOR,
                                   p_between_dates_curs OUT SYS_REFCURSOR,
                                   p_avg_curs           OUT SYS_REFCURSOR) as
  begin
    open p_order_curs for
      select c.name, count(*) as cnt
        from clients c
       inner join task_orders o
          on c.id = o.client_id
       group by c.name;
    open p_min_date_curs for
      select o.id, o.order_date, c.name
        from task_orders o
       inner join clients c
          on o.client_id = c.id
       WHERE o.order_date = (SELECT MIN(order_date) FROM task_orders);
    open p_max_date_curs for
      select o.id, o.order_date, c.name
        from task_orders o
       inner join clients c
          on o.client_id = c.id
       WHERE o.order_date = (SELECT max(order_date) FROM task_orders);
  
    open p_total_price_curs for
      select o.id, (sum(d.quantity * p.price)) as total
        from task_orders o
       inner join task_order_details d
          on o.id = d.order_id
       inner join task_products p
          on p.id = d.product_id
          group by o.id;
          
    open p_between_dates_curs for
      select c.name, o.id, o.order_date
        from task_orders o
        left join clients c
          on o.client_id = c.id
       WHERE o.order_date BETWEEN TO_DATE('11-02-2025', 'DD-MM-YYYY') AND
             TO_DATE('26-10-2025', 'DD-MM-YYYY');
  
    open p_avg_curs for
      select (sum(d.quantity * p.price) / count(*)) as avg_amount
        from task_orders o
       inner join task_order_details d
          on d.order_id = o.id
       inner join task_products p
          on d.product_id = p.id;
  end proc_get_order_details;

  procedure proc_get_balance(p_balance_curs OUT SYS_REFCURSOR,
                             p_status_curs  OUT SYS_REFCURSOR) as
  begin
    open p_balance_curs for
      select p.product,
             (i.balance - COALESCE(SUM(d.quantity), 0)) AS current_balance
        from task_products p
       inner join inventories i
          on i.product_id = p.id
       inner join task_order_details d
          on d.product_id = p.id
       inner join task_orders o
          on o.id = d.order_id
       GROUP BY p.product, i.balance;
  
    open p_status_curs for
      select c.name, p.product, s.status
        from clients c
       inner join task_orders o
          on o.client_id = c.id
       inner join task_order_details d
          on d.order_id = o.id
       inner join task_products p
          on d.product_id = p.id
       inner join task_status s
          on o.status_id = s.id;
  end proc_get_balance;

  procedure proc_employee_order(p_employee_id number,
                                p_order_id    number,
                                p_status_id   number) as
  begin
    update task_orders
       set status_id = p_status_id, employee_id = p_employee_id
     where p_order_id = id;
  
  end proc_employee_order;

  procedure proc_get_emp_order(p_order_cur      out sys_refcursor,
                               p_non_order_curs out sys_refcursor) as
  begin
    open p_order_cur for
      select e.name, count(*) as cnt
        from task_employees e
       inner join task_orders o
          on e.id = o.employee_id
       group by e.name;
  
    open p_non_order_curs for
      select e.name
        from task_employees e
       where e.id not in (select o.employee_id from task_orders o);
  end proc_get_emp_order;
end pkg_tasks_orders;
/


prompt Done
spool off
set define on
