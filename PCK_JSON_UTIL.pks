CREATE OR REPLACE package PCK_JSON_UTIL
IS
 /*
     **************************************************************************************************
     #
     # MODIFICATION HISTORY:
     #
     # When        Who             Activity#                What
     # ----        --------------  --------------        ---------------------------
     # 11/03/2018  Karthikeyan     JSON_UTIL               Initial Version
     #
     # Copyright (c) 
     # All Rights Reserved.
     #
     # No part of this software may be reproduced or transmitted in any
     # form or by any means,  electronic,  mechanical,  photocopying,
     # recording or otherwise,  without the prior written consent of
     # Karthikeyan R Swaminathan
     #
     # Internal Use Only
     #
     **************************************************************************************************
     */


--
  type tp_json_value is record ( json_type varchar2(1)
                               , idx pls_integer
                               );
  type tp_jv_indexes is table of number;
--
  function jv
  return tp_json_value;
--
  function jv( p_val varchar2 character set any_cs )
  return tp_json_value;
--
  function jv( p_cval clob character set any_cs )
  return tp_json_value;
--
  function jv( p_val date, p_fmt varchar2 := null )
  return tp_json_value;
--
  function jv( p_val number )
  return tp_json_value;
--
  function jv( p_val boolean )
  return tp_json_value;
--
  function jv( p_val varchar2, p_true varchar2 )
  return tp_json_value;
--
  function jv
    ( p_val blob
    , p_how pls_integer := 2 -- 1 => blob as hex-string
                             -- 2 => blob as base64 encoded string
                             -- 3 => blob as array of base64 encoded strings
    )
  return tp_json_value;
--
  function add_member
    ( p_json  tp_json_value
    , p_name  tp_json_value
    , p_value tp_json_value
    )
  return tp_json_value;
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  tp_json_value
    , p_value tp_json_value
    );
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  varchar2
    , p_value tp_json_value
    );
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  varchar2
    , p_value varchar2 character set any_cs
    );
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  varchar2
    , p_value number
    );
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  varchar2
    , p_value date
    , p_fmt varchar2 := null
    );
--
  function add_item
    ( p_json tp_json_value
    , p_value tp_json_value
    )
  return tp_json_value;
--
  procedure add_item
    ( p_json in out tp_json_value
    , p_value tp_json_value
    );
--
  procedure add_item
    ( p_json in out tp_json_value
    , p_value varchar2 character set any_cs
    );
--
  procedure add_item
    ( p_json in out tp_json_value
    , p_value number
    );
--
  procedure add_item
    ( p_json in out tp_json_value
    , p_value date
    , p_fmt varchar2 := null
    );
--
  function json -- create an object
    ( n1 varchar2      , v1 tp_json_value
    , n2 varchar2 := '', v2 tp_json_value := null
    , n3 varchar2 := '', v3 tp_json_value := null
    , n4 varchar2 := '', v4 tp_json_value := null
    , n5 varchar2 := '', v5 tp_json_value := null
    , n6 varchar2 := '', v6 tp_json_value := null
    , n7 varchar2 := '', v7 tp_json_value := null
    , n8 varchar2 := '', v8 tp_json_value := null
    )
  return tp_json_value;
--
  function json -- create an array
    ( v1 tp_json_value
    , v2 tp_json_value := null
    , v3 tp_json_value := null
    , v4 tp_json_value := null
    , v5 tp_json_value := null
    , v6 tp_json_value := null
    , v7 tp_json_value := null
    , v8 tp_json_value := null
    )
  return tp_json_value;
--
  function json -- create an array
    ( p_rc sys_refcursor
    , p_date_fmt varchar2 := null
    , p_raw pls_integer := 2 -- 1 => include raws as hex-string
                             -- 2 => include raws as base64 encoded string
                             -- 3 => include raws as array of base64 encoded strings
    , p_blob pls_integer := 0 -- 1 => include blobs as hex-string
                              -- 2 => include blobs as base64 encoded string
                              -- 3 => include blobs as array of base64 encoded strings
    , p_check_boolean_strings boolean := false
    )
  return tp_json_value;
--
  function json( p_json clob character set any_cs ) -- parses a JSON-string
  return tp_json_value;
--
  function json( p_xml xmltype
               , p_incl_root boolean := false
               , p_compact_object boolean := true
               , p_compact_array boolean := true
               )
  return tp_json_value;
--
  function json
    ( p_ad anydata
    , p_date_fmt varchar2 := null
    , p_raw pls_integer := 2 -- 1 => include raws as hex-string
                             -- 2 => include raws as base64 encoded string
                             -- 3 => include raws as array of base64 encoded strings
    , p_blob pls_integer := 0 -- 1 => include blobs as hex-string
                              -- 2 => include blobs as base64 encoded string
                              -- 3 => include blobs as array of base64 encoded strings
    )
  return tp_json_value;
--
/* json_ec returns by default a JSON-array
** In case you want to return the first entry of that array as a JSON-object use p_return_object = 'Y'
** In case you want to return a nested cursor to return a JSON-object, give the cursor column a alias starting with p_return_object_pre
** For example
**   select cursor( select * from dual ) ROIOA_dual from dual
*/
function json_ec -- create an array
    ( p_rc in out sys_refcursor
    , p_date_fmt varchar2 := null
    , p_raw pls_integer := 2 -- 1 => include raws as hex-string
                             -- 2 => include raws as base64 encoded string
                             -- 3 => include raws as array of base64 encoded strings
    , p_blob pls_integer := 0 -- 1 => include blobs as hex-string
                              -- 2 => include blobs as base64 encoded string
                              -- 3 => include blobs as array of base64 encoded strings
    , p_check_boolean_strings varchar2 := 'N'
    , p_return_object varchar2 := 'N'
    , p_return_object_pre varchar2 := 'ROIOA_'
    )
  return tp_json_value;
--
  function get_json_type( p_val tp_json_value )
  return varchar2;
--
  function get_string
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs := null
    , p_charset varchar2 character set any_cs := null  -- set charset of result
    )
  return varchar2 character set p_charset%charset;
--
  function get_string_clob
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs := null
    , p_charset varchar2 character set any_cs := null  -- set charset of result
    )
  return clob character set p_charset%charset;
--
  function get_number
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs := null
    )
  return number;
--
  function get_boolean
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs := null
    )
  return boolean;
--
  function get_date
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs := null
    , p_fmt varchar2 := null
    )
  return date;
--
  function get_count( p_val tp_json_value )
  return pls_integer;
--
  function get_name( p_val tp_json_value, p_idx pls_integer )
  return varchar2;
--
  function get_value( p_val tp_json_value, p_idx pls_integer )
  return tp_json_value;
--
  function path_get
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs
    )
  return tp_json_value;
--
  procedure free;
--
  procedure free( p_val tp_json_value );
--
  function stringify( p_val tp_json_value
                    , p_inc pls_integer := null -- pretty print increment
                    , p_xxx pls_integer := null -- # spaces after colon
                    , p_ind pls_integer := null -- do not use, for internal usage only
                    )
  return clob;
--
  function stringify
    ( p_rc sys_refcursor
    , p_date_fmt varchar2 := null
    , p_raw pls_integer := 2 -- 1 => include raws as hex-string
                             -- 2 => include raws as base64 encoded string
                             -- 3 => include raws as array of base64 encoded strings
    , p_blob pls_integer := 0 -- 1 => include blobs as hex-string
                              -- 2 => include blobs as base64 encoded string
                              -- 3 => include blobs as array of base64 encoded strings
    , p_check_boolean_strings varchar2 := 'N'
    )
  return clob;
--
  function stringify_ec
    ( p_rc sys_refcursor
    , p_date_fmt varchar2 := null
    , p_raw pls_integer := 2 -- 1 => include raws as hex-string
                             -- 2 => include raws as base64 encoded string
                             -- 3 => include raws as array of base64 encoded strings
    , p_blob pls_integer := 0 -- 1 => include blobs as hex-string
                              -- 2 => include blobs as base64 encoded string
                              -- 3 => include blobs as array of base64 encoded strings
    , p_check_boolean_strings varchar2 := 'N'
    , p_return_object varchar2 := 'N'
    , p_return_object_pre varchar2 := 'ROIOA_'
    )
  return clob;
--
  procedure htp( p_val tp_json_value
               , p_add_json_header boolean := true
               , p_jsonp varchar2 := null
               , p_free boolean := true
               );
--
  function to_xmltype
    ( p_val tp_json_value
    , p_root varchar2 := null
    , p_array_item varchar2 := null
    , p_free varchar2 := 'Y'
    )
  return xmltype;
--
  function to_xmltype
    ( p_json clob character set any_cs
    , p_root varchar2 := null
    , p_array_item varchar2 := null
    , p_free varchar2 := 'Y'
    )
  return xmltype;
--
  procedure set_default_date_fmt( p_fmt varchar2 );
--
  function qjson( p_json clob character set any_cs ) -- parses a JSON-string
  return number;
--
  function qget_string
    ( p_val number
    , p_path varchar2 character set any_cs := null
    , p_charset varchar2 character set any_cs := null  -- set charset of result
    )
  return varchar2 character set p_charset%charset;
--
  function qget_string_clob
    ( p_val number
    , p_path varchar2 character set any_cs := null
    , p_charset varchar2 character set any_cs := null  -- set charset of result
    )
  return clob character set p_charset%charset;
--
  function qget_number
    ( p_val number
    , p_path varchar2 character set any_cs := null
    )
  return number;
--
  function qget_boolean
    ( p_val number
    , p_path varchar2 character set any_cs
    , p_true varchar2 := 'TRUE'
    , p_false varchar2 := 'FALSE'
    )
  return varchar2;
--
  function qget_date
    ( p_val number
    , p_path varchar2 character set any_cs := null
    , p_fmt varchar2 := null
    )
  return date;
--
  function qpath_get
    ( p_val number
    , p_path varchar2 character set any_cs
    )
  return number;
--
  function qget_array
    ( p_val number
    , p_path varchar2 character set any_cs := null
    )
  return tp_jv_indexes pipelined;
end;
/