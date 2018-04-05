# ORA_JSON
Generating JSON Data from Oracle Tables Using Custom Oracle Package - for 11g 

	Oracle provided support to generate JSON using SQL/JSON functions starting Oracle Database Release 12c. 

	However, there were many live databases running with older Oracle release version which mandates a support for generating JSON data in more flexible and quick way. Using this Oracle package, we can able to generate JSON format data staright out of the tables. 

# DEMO
Step 1: Execute the setup scripts to create sample data. 

Step 2: Compile the pck_util_json.pks and pck_util_json.pkb – This step will create the core Oracle package which we will use to create the JSON data.

Step 3: Compile the gen_json_cust_ord_det.fnc function – This step will create the wrapper object which we use to pass data to our core package. 

Step 4: Execute the wrapper function – This step will produce the JSON data as required. 

# Sample 1:

SELECT gen_json_cust_ord_det(1) 
FROM DUAL;

JSON Output:
{  
  "customer_name":"EricCartman",
  "order_count":2,
  "orders_details":[  
    {  
      "order_id":1,
      "order_date":"2018-04-05",
      "item_id":845,
      "item_name":"Meteor Impact Survival Kit",
      "item_unit_price":299,
      "item_quantity":1
    },
    {  
      "order_id":2,
      "order_date":"2018-04-05",
      "item_id":232,
      "item_name":"Rubber Christmas Tree",
      "item_unit_price":65,
      "item_quantity":1
    },
    {  
      "order_id":2,
      "order_date":"2018-04-05",
      "item_id":429,
      "item_name":"Air Guitar",
      "item_unit_price":9.99,
      "item_quantity":4
    }
  ]
}


# Sample 2:

SELECT gen_json_cust_ord_det(3) 
FROM DUAL;

JSON Output:-
{  
  "customer_name":"KyleBrofloski",
  "order_count":1,
  "orders_details":[  
    {  
      "order_id":3,
      "order_date":"2018-04-05",
      "item_id":122,
      "item_name":"Potato Gun",
      "item_unit_price":29.99,
      "item_quantity":1
    }
  ]
}


