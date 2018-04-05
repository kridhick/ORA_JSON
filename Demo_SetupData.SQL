drop table customers;
drop table items;
drop table orders;
drop table lineitems;

CREATE TABLE customers (
    cust_id number,    
    first varchar2(30),  
    last varchar2(30),
    join_date timestamp);

insert into customers values (1, 'Eric', 'Cartman', SYSDATE);
insert into customers values (2, 'Kenny', 'McCormick', SYSDATE);
insert into customers values (3, 'Kyle', 'Brofloski', SYSDATE);
insert into customers values (4, 'Stan', 'Marsh', SYSDATE);

 

CREATE TABLE items (
    item_id number, 
    name    varchar2(30),  
    price   number(5,2),
    stock_quantity number);

insert into items values (122, 'Potato Gun', 29.99, 10);
insert into items values (232, 'Rubber Christmas Tree', 65.00, 0);
insert into items values (345, 'Border Patrol Costume', 19.99, 20);
insert into items values (845, 'Meteor Impact Survival Kit', 299.00, 0);
insert into items values (429, 'Air Guitar', 9.99, 14);
commit;

 

CREATE TABLE orders (
    order_id number,
    cust_id number, 
    order_date timestamp);


insert into orders values (1, 1, SYSDATE);
insert into orders values (2, 1, SYSDATE);
insert into orders values (3, 3, SYSDATE);
insert into orders values (4, 2, SYSDATE);

 


CREATE TABLE lineitems (
    order_id number, 
    item_id  number,
    quantity number);

insert into lineitems values(1, 845, 1);
insert into lineitems values(2, 232, 1);
insert into lineitems values(2, 429, 4);
insert into lineitems values(3, 122, 1);
insert into lineitems values(4, 345, 1);
commit;