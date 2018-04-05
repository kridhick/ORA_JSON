CREATE OR REPLACE FUNCTION gen_json_cust_ord_det (pin_customer_id NUMBER)
   RETURN CLOB
IS
   CURSOR c_cust
   IS
      SELECT cust.FIRST,
             cust.LAST,
             cust.cust_id,
             (SELECT COUNT (order_id)
                FROM orders ord
               WHERE ord.cust_id = cust.cust_id)
                AS ordercount
        FROM customers cust
       WHERE cust.cust_id = pin_customer_id;


   r_cust    c_cust%ROWTYPE;
   l_cust    pck_json_util.tp_json_value;
   l_order   pck_json_util.tp_json_value;
   l_rv      CLOB;
BEGIN
   OPEN c_cust;

   FETCH c_cust INTO r_cust;

   CLOSE c_cust;

   DBMS_LOB.createtemporary (l_rv, TRUE, DBMS_LOB.call);
   l_cust :=
      pck_json_util.json ('customer_name',
                          mpd.pck_json_util.jv (r_cust.FIRST || r_cust.LAST),
                          'order_count',
                          pck_json_util.jv (r_cust.ordercount));

   FOR r_orders
      IN (SELECT ord.order_id,
                 TRUNC (ord.order_date) AS order_date,
                 lineitems.item_id,
                 item.name,
                 item.price,
                 lineitems.quantity
            FROM customers cust
                 INNER JOIN orders ord ON cust.cust_id = ord.cust_id
                 INNER JOIN lineitems lineitems
                    ON lineitems.order_id = ord.order_id
                 INNER JOIN items item ON lineitems.item_id = item.item_id
           WHERE cust.cust_id = r_cust.cust_id)
   LOOP
      l_order :=
         pck_json_util.add_item (l_order,
                                 pck_json_util.json (
                                    'order_id',
                                    pck_json_util.jv (r_orders.order_id),
                                    'order_date',
                                    pck_json_util.jv (r_orders.order_date),
                                    'item_id',
                                    pck_json_util.jv (r_orders.item_id),
                                    'item_name',
                                    pck_json_util.jv (r_orders.name),
                                    'item_unit_price',
                                    pck_json_util.jv (r_orders.price),
                                    'item_quantity',
                                    pck_json_util.jv (r_orders.quantity)));
   END LOOP;

   IF NVL (l_order.json_type, 'NULL') <> 'NULL'
   THEN
      pck_json_util.add_member (l_cust, 'orders_details', l_order);
   END IF;

   l_rv := pck_json_util.stringify (l_cust);

   pck_json_util.free;
   RETURN l_rv;
END gen_json_cust_ord_det;