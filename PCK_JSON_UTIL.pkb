CREATE OR REPLACE package body PCK_JSON_UTIL
IS

/*
     **************************************************************************************************
     #
     # MODIFICATION HISTORY:
     #
     # When        Who             Activity#                What
     # ----        --------------  --------------        ---------------------------
     # 05/01/2017  Karthikeyan     JSON_UTIL             Initial Version
     #
     # 
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
  type tp_json_values is table of tp_json_value index by pls_integer;
  type tp_json is table of tp_json_values index by pls_integer;
--
  type tp_vstrings is table of varchar2(32767) index by pls_integer;
  type tp_nstrings is table of nvarchar2(32767) index by pls_integer;
  type tp_clobs is table of clob index by pls_integer;
  type tp_numbers is table of number index by pls_integer;
--
  g_vstrings tp_vstrings;
  g_nstrings tp_nstrings;
  g_clobs tp_clobs;
  g_numbers tp_numbers;
  g_json tp_json;
  --c_date_iso8601 constant varchar2(30) := 'yyyy-mm-dd"T"hh24:mi:ss"Z"';
  c_date_iso8601 constant varchar2(30) := 'yyyy-mm-dd';
  g_date_fmt varchar2(150 char) := c_date_iso8601;
--
  function vstringify( p_val tp_json_value
                     , p_inc pls_integer := null -- pretty print increment
                     , p_xxx pls_integer := null -- # spaces after colon
                     , p_ind pls_integer := null -- pretty print current indent
                     )
  return varchar2;
--
  function create_empty( p_json_type varchar2 )
  return tp_json_value
  is
    l_jv tp_json_value;
  begin
    l_jv.json_type := p_json_type;
    l_jv.idx := g_json.count;
    g_json( l_jv.idx )(0) := l_jv;
    return l_jv;
  end;
--
  function jv
  return tp_json_value
  is
    l_rv tp_json_value;
  begin
    l_rv.json_type := 'E';
    return l_rv;
  end;
--
  function jv( p_val varchar2 character set any_cs )
  return tp_json_value
  is
    l_rv tp_json_value;
  begin
    if isnchar( p_val )
    then
      l_rv.json_type := 'v';
      l_rv.idx := g_nstrings.count;
      g_nstrings( l_rv.idx ) := p_val;
    else
      l_rv.json_type := 'V';
      l_rv.idx := g_vstrings.count;
      g_vstrings( l_rv.idx ) := p_val;
    end if;
    return l_rv;
  end;
--
  function jv( p_cval clob character set any_cs )
  return tp_json_value
  is
    l_rv tp_json_value;
  begin
    l_rv.json_type := 'C';
    l_rv.idx := g_clobs.count;
    g_clobs( l_rv.idx ) := p_cval;
    return l_rv;
  end;
--
  function jv( p_val date, p_fmt varchar2 := null )
  return tp_json_value
  is
    l_fmt varchar2(3999);
    l_rv tp_json_value;
  begin
    if p_val is null
    then
      l_rv := jv;
    else
      l_rv.json_type := 'V';
      l_rv.idx := g_vstrings.count;
      l_fmt := coalesce( p_fmt, g_date_fmt, c_date_iso8601 );
      if l_fmt = c_date_iso8601
      then
-- check for c_date_iso8601 and convert to UTC, the Z means Zulu = Zero, i.e. use UTC+0:00
        g_vstrings( l_rv.idx ) := to_char( sys_extract_utc( cast( p_val as timestamp ) ), l_fmt );
      else
        g_vstrings( l_rv.idx ) := to_char( p_val, l_fmt );
      end if;
    end if;
    return l_rv;
  end;
--
  function jv( p_val number )
  return tp_json_value
  is
    l_rv tp_json_value;
  begin
    if p_val is null
    then
      l_rv := jv;
    else
      l_rv.json_type := 'N';
      l_rv.idx := g_numbers.count;
      g_numbers( l_rv.idx ) := p_val;
    end if;
    return l_rv;
  end;
--
  function jv( p_val boolean )
  return tp_json_value
  is
    l_rv tp_json_value;
  begin
    if p_val is null
    then
      l_rv := jv;
    else
      l_rv.json_type := 'B';
      l_rv.idx := case when p_val then 1 else 0 end;
    end if;
    return l_rv;
  end;
--
  function jv( p_val varchar2, p_true varchar2 )
  return tp_json_value
  is
    l_rv tp_json_value;
  begin
    if p_val is null
    then
      l_rv := jv;
    else
      l_rv.json_type := 'B';
      l_rv.idx := case when p_val = p_true then 1 else 0 end;
    end if;
    return l_rv;
  end;
--
  function jv
    ( p_val blob
    , p_how pls_integer := 2 -- 1 => blob as hex-string
                             -- 2 => blob as base64 encoded string
                             -- 3 => blob as array of base64 encoded strings
    )
  return tp_json_value
  is
    tmp varchar2(32767);
    tmpc clob;
    r1 raw(32767);
    l_jv tp_json_value;
    l_size pls_integer;
    raws_on_line pls_integer;
  begin
    if p_val is null
    then
      if p_how in ( 1, 2 )
      then
        return jv;
      else
        return create_empty( 'A' );
      end if;
    end if;
    if p_how in ( 1, 2 )
    then
      l_size := 16383;
      dbms_lob.createtemporary( tmpc, true, dbms_lob.call );
      for i in 0 .. floor( ( dbms_lob.getlength( p_val ) - 1 ) / l_size )
      loop
        r1 := dbms_lob.substr( p_val, l_size, i * l_size + 1 );
        if p_how = 1
        then
          tmp := rawtohex( r1 );
        else
          tmp := utl_raw.cast_to_varchar2( utl_encode.base64_encode( r1 ) );
        end if;
        dbms_lob.writeappend( tmpc, length( tmp ), tmp );
      end loop;
      l_jv := jv( tmpc );
      dbms_lob.freetemporary( tmpc );
      return l_jv;
    end if;
    raws_on_line := 6;
    loop
      tmp := utl_raw.cast_to_varchar2( utl_encode.base64_encode( utl_raw.copies( '00', raws_on_line ) ) );
      if (  instr( tmp, chr(10) ) > 0
         or instr( tmp, chr(13) ) > 0
         )
      then
        tmp := rtrim( tmp, chr(10) || chr(13) );
        if (  instr( tmp, chr(10) ) > 0
           or instr( tmp, chr(13) ) > 0
           )
        then
          raws_on_line := raws_on_line - 3;
        end if;
        exit;
      end if;
      raws_on_line := raws_on_line + 3;
    end loop;
    for i in 0 .. floor( ( dbms_lob.getlength( p_val ) - 1 ) / raws_on_line )
    loop
      r1 := dbms_lob.substr( p_val, raws_on_line, i * raws_on_line + 1 );
      tmp := utl_raw.cast_to_varchar2( utl_encode.base64_encode( r1 ) );
      add_item( l_jv, jv( rtrim( tmp, chr(10) || chr(13) ) ) );
    end loop;
    return l_jv;
  end;
--
  function add_member
    ( p_json  tp_json_value
    , p_name  tp_json_value
    , p_value tp_json_value
    )
  return tp_json_value
  is
    l_cnt pls_integer;
    l_jv tp_json_value;
  begin
    if p_name.json_type not in ( 'V', 'v', 'C', 'c' )
    then
      return null;
    end if;
    if p_json.json_type is not null
    then
      if p_json.json_type != 'O'
      then
        return null;
      end if;
      l_jv := p_json;
    else
      l_jv := create_empty( 'O' );
    end if;
    l_cnt := g_json( l_jv.idx ).count;
    g_json( l_jv.idx )( l_cnt ) := p_name;
    g_json( l_jv.idx )( l_cnt + 1 ) := p_value;
    return l_jv;
  end;
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  tp_json_value
    , p_value tp_json_value
    )
  is
  begin
    p_json := add_member( p_json, p_name, p_value );
  end;
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  varchar2
    , p_value tp_json_value
    )
  is
  begin
    add_member( p_json, jv( p_name ), p_value );
  end;
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  varchar2
    , p_value varchar2 character set any_cs
    )
  is
  begin
    add_member( p_json, jv( p_name ), jv( p_value ) );
  end;
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  varchar2
    , p_value number
    )
  is
  begin
    add_member( p_json, jv( p_name ), jv( p_value ) );
  end;
--
  procedure add_member
    ( p_json  in out tp_json_value
    , p_name  varchar2
    , p_value date
    , p_fmt varchar2 := null
    )
  is
  begin
    add_member( p_json, jv( p_name ), jv( p_value, p_fmt ) );
  end;
--
  function add_item
    ( p_json tp_json_value
    , p_value tp_json_value
    )
  return tp_json_value
  is
    l_jv tp_json_value;
  begin
    if p_json.json_type is not null
    then
      if p_json.json_type != 'A'
      then
        return null;
      end if;
      l_jv := p_json;
    else
      l_jv := create_empty( 'A' );
    end if;
    g_json( l_jv.idx )( g_json( l_jv.idx ).count ) := p_value;
    return l_jv;
  end;
--
  procedure add_item
    ( p_json in out tp_json_value
    , p_value tp_json_value
    )
  is
  begin
    p_json := add_item( p_json, p_value );
  end;
--
  procedure add_item
    ( p_json in out tp_json_value
    , p_value varchar2 character set any_cs
    )
  is
  begin
    p_json := add_item( p_json, jv( p_value ) );
  end;
--
  procedure add_item
    ( p_json in out tp_json_value
    , p_value number
    )
  is
  begin
    p_json := add_item( p_json, jv( p_value ) );
  end;
--
  procedure add_item
    ( p_json in out tp_json_value
    , p_value date
    , p_fmt varchar2 := null
    )
  is
  begin
    p_json := add_item( p_json, jv( p_value, p_fmt ) );
  end;
--
  function json
    ( n1 varchar2, v1 tp_json_value
    , n2 varchar2 := '', v2 tp_json_value := null
    , n3 varchar2 := '', v3 tp_json_value := null
    , n4 varchar2 := '', v4 tp_json_value := null
    , n5 varchar2 := '', v5 tp_json_value := null
    , n6 varchar2 := '', v6 tp_json_value := null
    , n7 varchar2 := '', v7 tp_json_value := null
    , n8 varchar2 := '', v8 tp_json_value := null
    )
  return tp_json_value
  is
    l_jv tp_json_value;
  begin
    l_jv := add_member( null, jv( n1 ), v1 );
    if l_jv.idx is not null and n2 is not null and v2.json_type is not null
    then
      l_jv := add_member( l_jv, jv( n2 ), v2 );
    end if;
    if l_jv.idx is not null and n3 is not null and v3.json_type is not null
    then
      l_jv := add_member( l_jv, jv( n3 ), v3 );
    end if;
    if l_jv.idx is not null and n4 is not null and v4.json_type is not null
    then
      l_jv := add_member( l_jv, jv( n4 ), v4 );
    end if;
    if l_jv.idx is not null and n5 is not null and v5.json_type is not null
    then
      l_jv := add_member( l_jv, jv( n5 ), v5 );
    end if;
    if l_jv.idx is not null and n6 is not null and v6.json_type is not null
    then
      l_jv := add_member( l_jv, jv( n6 ), v6 );
    end if;
    if l_jv.idx is not null and n7 is not null and v7.json_type is not null
    then
      l_jv := add_member( l_jv, jv( n7 ), v7 );
    end if;
    if l_jv.idx is not null and n5 is not null and v8.json_type is not null
    then
      l_jv := add_member( l_jv, jv( n8 ), v8 );
    end if;
    return l_jv;
  end;
--
  function json
    ( v1 tp_json_value
    , v2 tp_json_value := null
    , v3 tp_json_value := null
    , v4 tp_json_value := null
    , v5 tp_json_value := null
    , v6 tp_json_value := null
    , v7 tp_json_value := null
    , v8 tp_json_value := null
    )
  return tp_json_value
  is
    l_jv tp_json_value;
  begin
    l_jv := add_item( null, v1 );
    if l_jv.idx is not null and v2.json_type is not null
    then
      l_jv := add_item( l_jv, v2 );
    end if;
    if l_jv.idx is not null and v3.json_type is not null
    then
      l_jv := add_item( l_jv, v3 );
    end if;
    if l_jv.idx is not null and v4.json_type is not null
    then
      l_jv := add_item( l_jv, v4 );
    end if;
    if l_jv.idx is not null and v5.json_type is not null
    then
      l_jv := add_item( l_jv, v5 );
    end if;
    if l_jv.idx is not null and v6.json_type is not null
    then
      l_jv := add_item( l_jv, v6 );
    end if;
    if l_jv.idx is not null and v7.json_type is not null
    then
      l_jv := add_item( l_jv, v7 );
    end if;
    if l_jv.idx is not null and v8.json_type is not null
    then
      l_jv := add_item( l_jv, v8 );
    end if;
    return l_jv;
  end;
--
$IF NOT DBMS_DB_VERSION.VER_LE_10 $THEN
  function cursor2array
    ( p_c integer
    , p_date_fmt varchar2
    , p_raw pls_integer
    , p_blob pls_integer
    , p_check_boolean_strings boolean
    )
  return tp_json_value
  is
    l_jv tp_json_value;
    l_obj tp_json_value;
    l_c integer := p_c;
    l_col_cnt integer;
    l_desc_tab dbms_sql.desc_tab3;
    c_col clob;
    nc_col nclob;
    d_col date;
    n_col number;
    v_col varchar2(32767);
    nv_col nvarchar2(32767);
    r_col raw(4000);
    b_col blob;
    ts_col timestamp;
    tz_col timestamp with time zone;
    l_offs integer;
    l_ad anydata;
    l_xml xmltype;
  begin
    dbms_sql.describe_columns3( l_c, l_col_cnt, l_desc_tab );
    for c in 1 .. l_col_cnt
    loop
      case
        when l_desc_tab( c ).col_type in ( 2, 100, 101 )
        then
          dbms_sql.define_column( l_c, c, n_col );
        when l_desc_tab( c ).col_type in ( 12, 178, 179 )
        then
          dbms_sql.define_column( l_c, c, d_col );
        when l_desc_tab( c ).col_type in ( 1, 9, 96 )
        then
          if l_desc_tab( c ).col_charsetform = 2
          then
            dbms_sql.define_column( l_c, c, nv_col, 32767 );
          else
            dbms_sql.define_column( l_c, c, v_col, 32767 );
          end if;
        when l_desc_tab( c ).col_type = 112
        then
          if l_desc_tab( c ).col_charsetform = 2
          then
            dbms_sql.define_column( l_c, c, nc_col );
          else
            dbms_sql.define_column( l_c, c, c_col );
          end if;
        when l_desc_tab( c ).col_type = 113 and p_blob in ( 1, 2, 3 )
        then
          dbms_sql.define_column( l_c, c, b_col );
        when l_desc_tab( c ).col_type = 23 and p_raw in ( 1, 2, 3 )
        then
          dbms_sql.define_column( l_c, c, r_col, 32767 );
        when l_desc_tab( c ).col_type in ( 180, 231 )
        then
          dbms_sql.define_column( l_c, c, ts_col );
        when l_desc_tab( c ).col_type = 181
        then
          dbms_sql.define_column( l_c, c, tz_col );
        when l_desc_tab( c ).col_type = 8
        then
          dbms_sql.define_column_long( l_c, c );
        when l_desc_tab( c ).col_type = 109 -- user-defined type
        then
          execute immediate '
            declare
              x ' || l_desc_tab( c ).col_schema_name || '.' || l_desc_tab( c ).col_type_name || ';
            begin dbms_sql.define_column( :t_c, :c, x );end;' using l_c, c;
        else
          null;
      end case;
    end loop;
--
    while dbms_sql.fetch_rows( l_c ) > 0
    loop
      l_obj := null;
      for c in 1 .. l_col_cnt
      loop
        case
          when l_desc_tab( c ).col_type in ( 2, 100, 101 )
          then
            dbms_sql.column_value( l_c, c, n_col );
            add_member( l_obj, l_desc_tab( c ).col_name, jv( n_col ) );
          when l_desc_tab( c ).col_type in ( 12, 178, 179 )
          then
            dbms_sql.column_value( l_c, c, d_col );
            add_member( l_obj, l_desc_tab( c ).col_name, jv( d_col, p_date_fmt ) );
          when l_desc_tab( c ).col_type in ( 1, 9, 96 )
          then
            if l_desc_tab( c ).col_charsetform = 2
            then
              dbms_sql.column_value( l_c, c, nv_col );
              add_member( l_obj, l_desc_tab( c ).col_name, jv( nv_col ) );
            else
              dbms_sql.column_value( l_c, c, v_col );
              if p_check_boolean_strings and upper( v_col ) in ( 'TRUE', 'FALSE' )
              then
                add_member( l_obj, l_desc_tab( c ).col_name, jv( upper( v_col ) = 'TRUE' ) );
              else
                add_member( l_obj, l_desc_tab( c ).col_name, jv( v_col ) );
              end if;
            end if;
          when l_desc_tab( c ).col_type = 112
          then
            if l_desc_tab( c ).col_charsetform = 2
            then
              dbms_sql.column_value( l_c, c, nc_col );
              add_member( l_obj, l_desc_tab( c ).col_name, jv( nc_col ) );
              if dbms_lob.istemporary( nc_col ) = 1
              then
                dbms_lob.freetemporary( nc_col );
              end if;
            else
              dbms_sql.column_value( l_c, c, c_col );
              add_member( l_obj, l_desc_tab( c ).col_name, jv( c_col ) );
              if dbms_lob.istemporary( c_col ) = 1
              then
                dbms_lob.freetemporary( c_col );
              end if;
            end if;
          when l_desc_tab( c ).col_type = 113 and p_blob in ( 1, 2, 3 )
          then
            dbms_sql.column_value( l_c, c, b_col );
            add_member( l_obj, l_desc_tab( c ).col_name, jv( b_col, p_blob ) );
          when l_desc_tab( c ).col_type = 23 and p_raw in ( 1, 2, 3 )
          then
            dbms_sql.column_value( l_c, c, r_col );
            add_member( l_obj, l_desc_tab( c ).col_name, jv( r_col, p_how => p_raw ) );
          when l_desc_tab( c ).col_type in ( 180, 231 )
          then
            dbms_sql.column_value( l_c, c, ts_col );
            add_member( l_obj, l_desc_tab( c ).col_name, jv( to_char( ts_col, p_date_fmt || 'xff' ) ) );
          when l_desc_tab( c ).col_type = 181
          then
            dbms_sql.column_value( l_c, c, tz_col );
            add_member( l_obj, l_desc_tab( c ).col_name, jv( to_char( tz_col, p_date_fmt || 'xff TZH:TZM' ) ) );
          when l_desc_tab( c ).col_type = 8
          then
            dbms_lob.createtemporary( c_col, true, dbms_lob.call );
            l_offs := 0;
            loop
              dbms_sql.column_value_long( l_c, c, 32767, l_offs, v_col, n_col );
              exit when n_col = 0;
              dbms_lob.writeappend( c_col, n_col, v_col );
              l_offs := l_offs + n_col;
            end loop;
            add_member( l_obj, l_desc_tab( c ).col_name, jv( c_col ) );
            dbms_lob.freetemporary( c_col );
          when l_desc_tab( c ).col_type = 109
          then
            if (   l_desc_tab( c ).col_schema_name = 'SYS'
               and l_desc_tab( c ).col_type_name = 'XMLTYPE'
               )
            then
              dbms_sql.column_value( l_c, c, l_xml );
              add_member( l_obj, l_desc_tab( c ).col_name, json( l_xml ) );
            elsif (   l_desc_tab( c ).col_schema_name = 'SYS'
                  and l_desc_tab( c ).col_type_name = 'ANYDATA'
                  )
            then
              dbms_sql.column_value( l_c, c, l_ad );
              add_member( l_obj, l_desc_tab( c ).col_name, json( l_ad, p_date_fmt, p_raw, p_blob ) );
            else
              execute immediate '
                declare
                  x ' || l_desc_tab( c ).col_schema_name || '.' || l_desc_tab( c ).col_type_name || q'~;
                begin
                  dbms_sql.column_value( :t_c, :c, x );
                  execute immediate 'begin :ad := anydata.convertobject( :x ); end;' using out :ad, x;
                exception
                  when others then
                    execute immediate 'begin :ad := anydata.convertcollection( :x ); end;' using out :ad, x;
                end;~' using l_c, c, out l_ad;
              add_member( l_obj, l_desc_tab( c ).col_name, json( l_ad, p_date_fmt, p_raw, p_blob ) );
            end if;
          else
            null;
        end case;
      end loop;
      add_item( l_jv, l_obj );
    end loop;
    dbms_sql.close_cursor( l_c );
    return l_jv;
  end;
--
$END
  function json
    ( p_rc sys_refcursor
    , p_date_fmt varchar2 := null
    , p_raw pls_integer := 2 -- 1 => include raws as hex-string
                             -- 2 => include raws as base64 encoded string
                             -- 3 => include raws as array of base64 encoded strings
    , p_blob pls_integer := 0 -- 1 => include blobs as hex-string
                              -- 2 => include blobs as base64 encoded string
                              -- 3 => include blobs as array of base64 encoded strings
    , p_check_boolean_strings boolean := false -- treat varchar2 values TRUE or FALSE as json boolean instead of json string
    )
  return tp_json_value
  is
    l_rc sys_refcursor := p_rc;
  begin
$IF DBMS_DB_VERSION.VER_LE_10 $THEN
    declare
      l_version varchar2(100);
      l_compat  varchar2(100);
    begin
      dbms_utility.db_version( l_version, l_compat );
      return jv( 'Not implemented in database version ' || l_version );
    end;
$ELSE
    return cursor2array( dbms_sql.to_cursor_number( l_rc )
                       , p_date_fmt
                       , p_raw
                       , p_blob
                       , p_check_boolean_strings
                       );
$END
  end;
--
  function json( p_json clob character set any_cs )
  return tp_json_value
  is
    l_jv tp_json_value;
    l_ind pls_integer;
    l_len pls_integer;
    l_tmp varchar2(1 char) character set p_json%charset;
    c_bs  constant varchar2(1 char) character set p_json%charset:= chr( 8 );   -- backspace
    c_ht  constant varchar2(1 char) character set p_json%charset := chr( 9 );  -- horizontal tab
    c_lf  constant varchar2(1 char) character set p_json%charset := chr( 10 ); -- line feed
    c_ff  constant varchar2(1 char) character set p_json%charset := chr( 12 ); -- form feed
    c_cr  constant varchar2(1 char) character set p_json%charset := chr( 13 ); -- carriage return
    c_sp  constant varchar2(1 char) character set p_json%charset := ' ';       -- space
    c_dq  constant varchar2(1 char) character set p_json%charset := '"';       -- double quote
    c_bsl constant varchar2(1 char) character set p_json%charset := '\';       -- back slash
    c_u   constant varchar2(1 char) character set p_json%charset := 'u';       -- u
    c_cm  constant varchar2(1 char) character set p_json%charset := ',';       -- comma
    c_sbo constant varchar2(1 char) character set p_json%charset := '[';       -- square bracket, open
    c_sbc constant varchar2(1 char) character set p_json%charset := ']';       -- square bracket, close
    c_co  constant varchar2(1 char) character set p_json%charset := ':';       -- colon
    c_cbo constant varchar2(1 char) character set p_json%charset := '{';       -- curly bracket, open
    c_cbc constant varchar2(1 char) character set p_json%charset := '}';       -- curly bracket, close
--
    procedure raise_eos( p_ind pls_integer, p_txt varchar2 )
    is
    begin
      if p_ind > l_len
      then
        raise_application_error( -20001, 'Reached end of string while looking for a ' || p_txt || ' at position ' || p_ind );
      end if;
    end;
--
    function skip_ws( p_ind in out pls_integer )
    return pls_integer
    is
    begin
      while dbms_lob.substr( p_json, 1, p_ind ) in ( c_sp, c_lf, c_cr, c_bs, c_ht, c_ff )
      loop
        p_ind := p_ind + 1;
      end loop;
      return p_ind;
    end;
--
    procedure skip_ws( p_ind in out pls_integer )
    is
      t_dummy pls_integer;
    begin
      t_dummy := skip_ws( p_ind );
    end;
--
    function parse_string( p_ind in out pls_integer, p_val out tp_json_value )
    return boolean
    is
      l_str nclob;
      l_tmp nvarchar2(1 char);
      l_vstr varchar2(32767) character set p_json%charset;
      l_pos pls_integer;
    begin
      raise_eos( skip_ws( p_ind ), 'JSON-string' );
      if dbms_lob.substr( p_json, 1, p_ind ) != c_dq
      then
        return false;
      end if;
      p_ind := p_ind + 1;
--
      l_pos := dbms_lob.instr( p_json, c_dq, p_ind );
      if l_pos = 0
      then
        raise_application_error( -20001, 'Didn''t find a closing " for string at position ' || p_ind );
      end if;
      begin
        l_vstr := dbms_lob.substr( p_json, l_pos - p_ind, p_ind );
        if instr( l_vstr, c_bsl ) = 0
        then
          p_ind := l_pos + 1;
          if isnchar( l_vstr ) and to_nchar( to_char( l_vstr ) ) = l_vstr
          then
            p_val := jv( to_char( l_vstr ) );
          else
            p_val := jv( l_vstr );
          end if;
          return true;
        end if;
      exception
        when others then -- expected only too large strings for varchar2
          null;
      end;
--
      dbms_lob.createtemporary( l_str, true, dbms_lob.call );
      loop
        raise_eos( p_ind, 'JSON-string' );
        l_tmp := dbms_lob.substr( p_json, 1, p_ind );
        if l_tmp = c_bsl
        then
          p_ind := p_ind + 1;
          raise_eos( p_ind, 'JSON-string' );
          l_tmp := dbms_lob.substr( p_json, 1, p_ind );
          if l_tmp = c_u
          then
            begin
              l_tmp := unistr( c_bsl || dbms_lob.substr( p_json, 4, p_ind + 1 ) );
            exception
              when others then -- when it was not a unicode escape character
                raise_application_error( -20001, 'error converting unicode character at position ' || p_ind );
            end;
            p_ind := p_ind + 4;
          else
            l_tmp := translate( l_tmp
                              , 'bfnrt'
                              , chr( 8 ) || chr( 12 ) || chr( 10 ) || chr( 13 ) || chr( 9 )
                              );
          end if;
        else
          exit when l_tmp = c_dq;
        end if;
        p_ind := p_ind + 1;
        dbms_lob.writeappend( l_str, 1, l_tmp );
      end loop;
      p_ind := p_ind + 1;
      begin
        if to_nchar( to_char( l_str ) ) = to_nchar( l_str )
        then
          p_val := jv( to_char( l_str ) );
        else
          p_val := jv( to_nchar( l_str ) );
        end if;
        dbms_lob.freetemporary( l_str );
      exception
        when others then
-- at this moment PCK_JSON_UTIL only supports no clob while parsing an input JSON string, no nclob
          p_val := jv( l_str );
      end;
      return true;
    end;
--
    function parse_value( p_ind in out pls_integer, p_val out tp_json_value )
    return boolean;
--
    function parse_array( p_ind in out pls_integer, p_arr out tp_json_value )
    return boolean
    is
      t_val tp_json_value;
      t_found boolean := false;
    begin
      raise_eos( skip_ws( p_ind ), 'JSON-array' );
      if dbms_lob.substr( p_json, 1, p_ind ) != c_sbo
      then
        return false;
      end if;
      p_ind := p_ind + 1;
      p_arr := create_empty( 'A' );
      loop
        l_tmp := dbms_lob.substr( p_json, 1, skip_ws( p_ind ) );
        exit when l_tmp = c_sbc;
        if t_found
        then
          if l_tmp != c_cm
          then
            raise_application_error( -20001, 'Didn''t find a array separator "," at position ' || p_ind );
          end if;
          p_ind := p_ind + 1;
        end if;
        raise_eos( skip_ws( p_ind ), 'JSON-array' );
        if not parse_value( p_ind, t_val )
        then
          raise_application_error( -20001, 'Didn''t find a array value at position ' || p_ind );
        end if;
        add_item( p_arr, t_val );
        t_found := true;
      end loop;
      p_ind := p_ind + 1;
      return true;
    end;
--
    function parse_object( p_ind in out pls_integer, p_obj out tp_json_value )
    return boolean
    is
      t_val tp_json_value;
      t_name tp_json_value;
      t_found boolean := false;
    begin
      raise_eos( skip_ws( p_ind ), 'JSON-object' );
      if dbms_lob.substr( p_json, 1, p_ind ) != c_cbo
      then
        return false;
      end if;
      p_ind := p_ind + 1;
      p_obj := create_empty( 'O' );
      loop
        l_tmp := dbms_lob.substr( p_json, 1, skip_ws( p_ind ) );
        exit when l_tmp = c_cbc;
        if t_found
        then
          if l_tmp != c_cm
          then
            raise_application_error( -20001, 'Didn''t find a member separator "," at position ' || p_ind );
          end if;
          p_ind := p_ind + 1;
        end if;
        raise_eos( skip_ws( p_ind ), 'JSON-object' );
        if not parse_string( p_ind, t_name )
        then
          raise_application_error( -20001, 'Didn''t find a pair string at position ' || p_ind );
        end if;
        raise_eos( skip_ws( p_ind ), 'JSON-object' );
        l_tmp := dbms_lob.substr( p_json, 1, skip_ws( p_ind ) );
        if l_tmp != c_co
        then
          raise_application_error( -20001, 'Didn''t find a pair separator ":" at position ' || p_ind );
        end if;
        p_ind := p_ind + 1;
        raise_eos( skip_ws( p_ind ), 'JSON-object' );
        if not parse_value( p_ind, t_val )
        then
          raise_application_error( -20001, 'Didn''t find a pair value at position ' || p_ind );
        end if;
        add_member( p_obj, t_name, t_val );
        t_found := true;
      end loop;
      p_ind := p_ind + 1;
      return true;
    end;
--
    function parse_value( p_ind in out pls_integer, p_val out tp_json_value )
    return boolean
    is
      fmt varchar2(200 char) character set p_json%charset;
      num_str varchar2(200 char) character set p_json%charset;
      l_tmp varchar2(5 char) character set p_json%charset;
      c_null  varchar2(4 char) character set p_json%charset := 'null';
      c_true  varchar2(4 char) character set p_json%charset := 'true';
      c_false varchar2(5 char) character set p_json%charset := 'false';
      c_num_allowed_chars varchar2(15 char) character set p_json%charset := '0123456789.eE+-';
      c_E varchar2(1 char) character set p_json%charset := 'E';
      c_eeee varchar2(4 char) character set p_json%charset := 'eeee';
    begin
      if (  parse_string( p_ind, p_val )
         or parse_object( p_ind, p_val )
         or parse_array( p_ind, p_val )
         )
      then
        return true;
      end if;
      l_tmp := dbms_lob.substr( p_json, 5, p_ind );
      if substr( l_tmp, 1, 4 ) = c_null
      then
        p_ind := p_ind + 4;
        p_val := jv();
        return true;
      elsif substr( l_tmp, 1, 4 ) = c_true
      then
        p_ind := p_ind + 4;
        p_val := jv( true );
        return true;
      elsif l_tmp = c_false
      then
        p_ind := p_ind + 5;
        p_val := jv( false );
        return true;
      end if;
      begin
        loop
          exit when p_ind > l_len;
          l_tmp := dbms_lob.substr( p_json, 1, p_ind );
          exit when instr( c_num_allowed_chars, l_tmp ) = 0;
          num_str := num_str || l_tmp;
          p_ind := p_ind + 1;
        end loop;
        fmt := translate( num_str, '.012345678+-', 'D999999999SS' );
        if instr( upper( fmt ), c_E ) > 0
        then
          fmt := substr( fmt, 1, instr( upper( fmt ), c_E ) - 1 );
          fmt := fmt || c_eeee;
        end if;
        p_val := jv( to_number( num_str, fmt, 'NLS_NUMERIC_CHARACTERS=.,' ) );
        return true;
      exception
        when others then
          raise_application_error( -20001, 'invalid number ' || num_str || ' at position ' || p_ind );
      end;
    end;
  begin
    l_len := dbms_lob.getlength( p_json );
    if p_json is null or l_len = 0
    then
      return create_empty( 'O' ); -- empty object
    end if;
    l_ind := 1;
    if (   parse_value( l_ind, l_jv )
       and skip_ws( l_ind ) >= l_len
       )
    then
      return l_jv;
    end if;
    return create_empty( 'O' ); -- empty object
  end;
--
  function json( p_xml xmltype
               , p_incl_root boolean := false
               , p_compact_object boolean := true
               , p_compact_array boolean := true
               )
  return tp_json_value
  is
    l_jv tp_json_value;
    l_root dbms_xmldom.domnode;
    l_doc dbms_xmldom.domdocument;
--
    function pn( p_nd dbms_xmldom.domnode )
    return tp_json_value
    is
      l_obj tp_json_value;
      l_arr tp_json_value;
      l_val tp_json_value;
      l_nd dbms_xmldom.domnode;
      l_nl dbms_xmldom.domnodelist;
      l_nnm dbms_xmldom.domnamednodemap;
      l_name varchar2(32767);
      l_text varchar2(32767);
      type tp_element is record
        ( namespace  varchar2(32767)
        , local_name varchar2(32767)
        , name       varchar2(32767)
        );
      l_element tp_element;
      type tp_names is table of tp_element index by l_name%type;
      l_names tp_names;
      l_obj_open boolean;
    begin
      l_nl := dbms_xslprocessor.selectnodes( p_nd, '*' ); -- only element nodes
      if p_compact_object
      then
        for i in 0 .. dbms_xmldom.getlength( l_nl ) - 1
        loop
          l_nd := dbms_xmldom.item( l_nl, i );
          dbms_xmldom.getexpandedname( l_nd, l_name ) ;
          dbms_xmldom.getlocalname( l_nd, l_element.local_name );
          l_element.name := dbms_xmldom.getnodename( l_nd );
          l_element.namespace := dbms_xmldom.getnamespace( dbms_xmldom.makeelement( l_nd ) );
          l_names( l_name ) := l_element;
        end loop;
        if l_names.count > 0
        then
          l_name := l_names.first;
          loop
            exit when l_name is null;
            l_element := l_names( l_name );
            if l_element.namespace is null
            then
              l_nl := dbms_xslprocessor.selectnodes( p_nd, l_element.local_name );
            else
              l_nl := dbms_xslprocessor.selectnodes( p_nd, l_element.local_name, l_element.namespace );
            end if;
            for i in 0 .. dbms_xmldom.getlength( l_nl ) - 1
            loop
              l_val := pn( dbms_xmldom.item( l_nl, i ) );
              if dbms_xmldom.getlength( l_nl ) > 1
              then
                add_item( l_arr, l_val );
              else
                add_member( l_obj, l_element.name, l_val );
              end if;
            end loop;
            if dbms_xmldom.getlength( l_nl ) > 1
            then
              if (   p_compact_array
                 and l_names.count = 1
                 and l_obj.json_type is null
-- check for text nodes
                 )
              then
                l_obj := l_arr;
              else
                add_member( l_obj, l_element.name, l_arr );
              end if;
              l_arr := null;
            end if;
            l_name := l_names.next( l_name );
          end loop;
        end if;
      else
        for i in 0 .. dbms_xmldom.getlength( l_nl ) - 1
        loop
          l_nd := dbms_xmldom.item( l_nl, i );
          l_val := pn( dbms_xmldom.item( l_nl, i ) );
          add_member( l_obj, dbms_xmldom.getnodename( l_nd ), l_val );
        end loop;
      end if;
--
      l_nnm := dbms_xmldom.getattributes( p_nd );
      for i in 0 .. dbms_xmldom.getlength( l_nnm ) - 1
      loop
        l_nd := dbms_xmldom.item( l_nnm, i );
        l_name := dbms_xmldom.getnodename( l_nd );
        if (   l_name = 'null'
           and l_obj.json_type is null
           and dbms_xmldom.getnodevalue( l_nd ) = 'true'
           )
        then
          l_obj := jv;
        else
          add_member( l_obj
                    , '@' || l_name
                    , jv( dbms_xmldom.getnodevalue( l_nd ) )
                    );
        end if;
      end loop;
--
      l_nl := dbms_xslprocessor.selectnodes( p_nd, 'text()' ); -- text nodes
      if dbms_xmldom.getlength( l_nl ) = 1
      then
        l_text := dbms_xmldom.getnodevalue( dbms_xmldom.item( l_nl, 0 ) );
        if l_text = 'null'
        then
          l_val := jv;
        elsif l_text in ( 'true', 'false' )
        then
          l_val := jv( l_text, 'true' );
        else
          l_val := jv( l_text );
        end if;
        if l_obj.json_type is null
        then
          l_obj := l_val;
        else
          add_member( l_obj, '#text', l_val );
        end if;
      elsif dbms_xmldom.getlength( l_nl ) > 1
      then
        for i in 0 .. dbms_xmldom.getlength( l_nl ) - 1
        loop
          l_val := jv( dbms_xmldom.getnodevalue( dbms_xmldom.item( l_nl, i ) ) );
          add_item( l_arr, l_val );
        end loop;
        if l_obj.json_type is null
        then
          l_obj := l_arr;
        else
          add_member( l_obj, '#text', l_arr );
        end if;
      end if;
      if l_obj.json_type is null
      then
        l_obj := create_empty( 'O' );
      end if;
      return l_obj;
    end;
  begin
    if p_xml is not null
    then
      l_doc := dbms_xmldom.newdomdocument( p_xml );
      l_root := dbms_xmldom.makenode( dbms_xmldom.getdocumentelement( l_doc ) );
      if not dbms_xmldom.isnull( l_root )
      then
        if p_incl_root
        then
          add_member( l_jv, dbms_xmldom.getnodename( l_root ), pn( l_root ) );
        else
          l_jv := pn( l_root );
        end if;
      end if;
      dbms_xmldom.freedocument( l_doc );
    end if;
    return l_jv;
  end;
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
  return tp_json_value
  is
    l_rv tp_json_value;
    d pls_integer;
    l_at anytype;
    d1 varchar2(100);
    d2 pls_integer;
    l_at2 anytype;
    l_attr_name varchar2(100);
    l_num_elems pls_integer;
    l_call varchar2(400);
--
    function get_type( p pls_integer )
    return varchar2
    is
    begin
      return case p
               when dbms_types.typecode_varchar         then 'varchar'
               when dbms_types.typecode_varchar2        then 'varchar2'
               when dbms_types.typecode_char            then 'char'
               when dbms_types.typecode_clob            then 'clob'
               when dbms_types.typecode_nchar           then 'nchar'
               when dbms_types.typecode_nvarchar2       then 'nvarchar2'
               when dbms_types.typecode_nclob           then 'nclob'
               when dbms_types.typecode_number          then 'number'
               when dbms_types.typecode_bfloat          then 'bfloat'
               when dbms_types.typecode_bdouble         then 'bdouble'
               when dbms_types.typecode_date            then 'date'
               when dbms_types.typecode_timestamp       then 'timestamp'
               when dbms_types.typecode_timestamp_tz    then 'timestamptz'
               when dbms_types.typecode_timestamp_ltz   then 'timestampltz'
               when dbms_types.typecode_raw             then 'raw'
               when dbms_types.typecode_blob            then 'blob'
               when dbms_types.typecode_namedcollection then 'collection'
               when dbms_types.typecode_object          then 'object'
             end;
    end;
  begin
    if p_ad is null
    then
      l_rv := create_empty( 'O' );
    else
      case p_ad.gettype( l_at )
        when dbms_types.typecode_varchar then
          l_rv := jv( p_ad.accessvarchar );
        when dbms_types.typecode_varchar2 then
          l_rv := jv( p_ad.accessvarchar2 );
        when dbms_types.typecode_char then
          l_rv := jv( p_ad.accesschar );
        when dbms_types.typecode_clob then
          l_rv := jv( p_ad.accessclob );
        when dbms_types.typecode_nchar then
          l_rv := jv( p_ad.accessnchar );
        when dbms_types.typecode_nvarchar2 then
          l_rv := jv( p_ad.accessnvarchar2 );
        when dbms_types.typecode_nclob then
          l_rv := jv( p_ad.accessnclob );
        when dbms_types.typecode_number then
          l_rv := jv( p_ad.accessnumber );
        when dbms_types.typecode_bfloat then
          l_rv := jv( p_ad.accessbfloat );
        when dbms_types.typecode_bdouble then
          l_rv := jv( p_ad.accessbdouble );
        when dbms_types.typecode_date then
          l_rv := jv( to_char( p_ad.accessdate, p_date_fmt ) );
        when dbms_types.typecode_timestamp then
          l_rv := jv( to_char( p_ad.accesstimestamp, p_date_fmt || 'Xff' ) );
        when dbms_types.typecode_timestamp_tz then
          l_rv := jv( to_char( p_ad.accesstimestamptz, p_date_fmt || 'Xff TZH:TZM' ) );
        when dbms_types.typecode_timestamp_ltz then
          l_rv := jv( to_char( p_ad.accesstimestampltz, p_date_fmt || 'Xff' ) );
        when dbms_types.typecode_raw then
          if p_raw in ( 1, 2, 3 )
          then
            l_rv := jv( p_ad.accessraw, p_how => p_raw );
          end if;
        when dbms_types.typecode_blob then
          if p_blob in ( 1, 2, 3 )
          then
            l_rv := jv( p_ad.accessblob, p_how => p_blob );
          end if;
        when dbms_types.typecode_namedcollection then
          l_rv := create_empty( 'A' );
          d := l_at.getattreleminfo( d2, d2, d2, d2, d2, d2, l_at, d1 );
          l_call := 'PCK_JSON_UTIL.add_item( rv, PCK_JSON_UTIL.json( ';
          l_call := l_call || 'anydata.convert' || get_type( d ) || '( x(i) )'; 
          l_call := l_call || ', :a, :b, :c ) );'; 
          execute immediate 'declare
  x ' || p_ad.gettypename || ';
  d pls_integer;
  i number;
  rv PCK_JSON_UTIL.tp_json_value;
begin
  d := anydata.getcollection( :ad, x );
  rv.json_type := ''A'';
  rv.idx := :idx;
  i := x.first;
  while i is not null
  loop
    ' || l_call || '
    i := x.next( i );
  end loop;
end;' using p_ad, l_rv.idx, p_date_fmt, p_raw, p_blob;
        when dbms_types.typecode_object then
          l_rv := create_empty( 'O' );
          d := l_at.getinfo( d2, d2, d2, d2, d2, d1, d1, d1, l_num_elems );
          for i in 1 .. l_num_elems
          loop
            d := l_at.getattreleminfo( i, d2, d2, d2, d2, d2, l_at2, l_attr_name ); 
--dbms_output.put_line( d || ' ' || l_attr_name || ' ' || get_type( d ) );
            l_call := 'PCK_JSON_UTIL.add_member( rv, ''';
            l_call := l_call || l_attr_name || ''', PCK_JSON_UTIL.json( ';
            l_call := l_call || 'anydata.convert' || get_type( d );
            l_call := l_call || '( x.' || l_attr_name || ' ), :a, :b, :c ) );'; 
            execute immediate 'declare
  x ' || p_ad.gettypename || ';
  d pls_integer;
  rv PCK_JSON_UTIL.tp_json_value;
begin
  d := anydata.getobject( :ad, x );
  rv.json_type := ''O'';
  rv.idx := :idx;
  ' || l_call || '
end;' using p_ad, l_rv.idx, p_date_fmt, p_raw, p_blob;
          end loop;
        else
          null;
      end case;
    end if;
    return l_rv;
  end;
--
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
  return tp_json_value
  is
    l_rv tp_json_value;
    l_c integer;
    l_col_cnt integer;
    l_desc_tab dbms_sql.desc_tab3;
    l_decl varchar2(32767);
    l_call varchar2(32767);
    l_fetch varchar2(32767);
  begin
$IF DBMS_DB_VERSION.VER_LE_10 $THEN
    declare
      l_version varchar2(100);
      l_compat  varchar2(100);
    begin
      dbms_utility.db_version( l_version, l_compat );
      return jv( 'Not implemented in database version ' || l_version );
    end;
$ELSE
    l_rv := create_empty( case when p_return_object = 'Y' then 'O' else 'A' end );
  $IF DBMS_DB_VERSION.VER_LE_11 $THEN
-- nested cursors are open, but can't be converted with dbms_sql.to_cursor_number
-- trying a fetch with an invalid number of "into targets" solves that
    declare
      t varchar2(650);
    begin
      t := 'declare x raw(1);begin fetch :r into x';
      for i in 1 .. 300
      loop
        t := t || ',x';
      end loop;
      execute immediate t || ';end;' using in out p_rc;
    exception
      when others then null;
    end;
  $END
    l_c := dbms_sql.to_cursor_number( p_rc );
    dbms_sql.describe_columns3( l_c, l_col_cnt, l_desc_tab );
    for c in 1 .. l_col_cnt
    loop
      case -- base on number in view all_tab_cols
        when l_desc_tab( c ).col_type in ( 2   -- NUMBER
                                         , 100 -- BINARY_FLOAT
                                         , 101 -- BINARY_DOUBLE
                                         ) then
          l_decl := l_decl || 'c' || c || ' number;' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c' || c; 
          l_call := l_call || '~#'; 
        when l_desc_tab( c ).col_type = 12 then  -- DATE
          l_decl := l_decl || 'c' || c || ' date;' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c' || c; 
          l_call := l_call || ',:pdf'; 
          l_call := l_call || '~#'; 
        when l_desc_tab( c ).col_type = 178 then -- TIME
          l_decl := l_decl || 'c' || c || ' time(9);' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!'; 
          l_call := l_call || 'to_char(c' || c ||',''hh24:mi:ss:ff'')'; 
          l_call := l_call || '~#'; 
        when l_desc_tab( c ).col_type = 179 then -- TIME WITH TIME ZONE
          l_decl := l_decl || 'c' || c || ' time(9) with time zone;' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!'; 
          l_call := l_call || 'to_char(c' || c ||',''hh24:mi:ss:ff TZH:TZM'')'; 
          l_call := l_call || '~#'; 
        when l_desc_tab( c ).col_type in ( 1  -- VARCHAR2
                                         , 9  -- VARCHAR
                                         , 96 -- CHAR
                                         ) then
          if l_desc_tab( c ).col_charsetform = 2
          then
            l_decl := l_decl || 'c' || c || ' nvarchar2(' || l_desc_tab( c ).col_max_len || ');' || chr(10);
          else
            l_decl := l_decl || 'c' || c || ' varchar2(' || l_desc_tab( c ).col_max_len || ');' || chr(10);
          end if;
          if upper( substr( p_check_boolean_strings, 1, 1 ) ) in ( 'Y', 'J', 'T' )
          then
            l_call := l_call || 'if upper(c' || c || ')in(''TRUE'',''FALSE'') then' || chr(10); 
            l_call := l_call || 'PCK_JSON_UTIL.add_member(ro,q''^' || l_desc_tab( c ).col_name || '^'',PCK_JSON_UTIL.jv(';
            l_call := l_call || 'upper(c' || c || ')=''TRUE''));' || chr(10);
            l_call := l_call || 'else' || chr(10); 
            l_call := l_call || 'PCK_JSON_UTIL.add_member(ro,q''^' || l_desc_tab( c ).col_name || '^'',PCK_JSON_UTIL.jv(c' || c || '));' || chr(10);
            l_call := l_call || 'end if;' || chr(10); 
          else
            l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c' || c;
            l_call := l_call || '~#'; 
          end if;           
        when l_desc_tab( c ).col_type = 112 -- CLOB
        then 
          if l_desc_tab( c ).col_charsetform = 2
          then
            l_decl := l_decl || 'c' || c || ' nclob;' || chr(10);
          else
            l_decl := l_decl || 'c' || c || ' clob;' || chr(10);
          end if;
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c' || c; 
          l_call := l_call || '~#'; 
        when l_desc_tab( c ).col_type = 113 -- BLOB
        then
          l_decl := l_decl || 'c' || c || ' blob;' || chr(10);
          if p_blob in ( 1, 2, 3 )
          then
            l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c'; 
            l_call := l_call || c || ',:pb~#';
          end if; 
        when l_desc_tab( c ).col_type = 23 -- RAW
        then
          l_decl := l_decl || 'c' || c || ' raw(' || l_desc_tab( c ).col_max_len || ');' || chr(10);
          if p_raw in ( 1, 2, 3 )
          then
            l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c'; 
            l_call := l_call || c || ',p_how=>:pr~#';
          end if; 
        when l_desc_tab( c ).col_type = 180 -- TIMESTAMP
        then
          l_decl := l_decl || 'c' || c || ' timestamp(' || l_desc_tab( c ).col_scale || ');' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!'; 
          l_call := l_call || 'to_char(c' || c || ',:tsf)~#'; 
        when l_desc_tab( c ).col_type = 181 -- TIMESTAMP WITH TIME ZONE
        then
          l_decl := l_decl || 'c' || c || ' timestamp(' || l_desc_tab( c ).col_scale || ') with time zone;' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!'; 
          l_call := l_call || 'to_char(c' || c || ',:tsf||'' TZH:TZM'')~#'; 
        when l_desc_tab( c ).col_type = 231 -- -- TIMESTAMP WITH LOCAL TIME ZONE
        then
          l_decl := l_decl || 'c' || c || ' timestamp(' || l_desc_tab( c ).col_scale || ') with local time zone;' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!'; 
          l_call := l_call || 'to_char(c' || c || ',:tsf||'' TZH:TZM'')~#'; 
        when l_desc_tab( c ).col_type = 182 -- INTERVAL YEAR TO MONTH
        then
          l_decl := l_decl || 'c' || c || ' interval year(' || l_desc_tab( c ).col_precision || ') to month;' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!'; 
          l_call := l_call || 'to_char(c' || c || ')~#'; 
        when l_desc_tab( c ).col_type = 183 -- INTERVAL DAY TO SECOND
        then
          l_decl := l_decl || 'c' || c || ' interval day(' || l_desc_tab( c ).col_precision || ') to second(' || l_desc_tab( c ).col_scale || ');' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!'; 
          l_call := l_call || 'to_char(c' || c || ')~#'; 
        when l_desc_tab( c ).col_type in ( 11, 69 ) then
          l_decl := l_decl || 'c' || c || ' rowid;' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c' || c; 
          l_call := l_call || '~#'; 
        when l_desc_tab( c ).col_type = 208 then
          l_decl := l_decl || 'c' || c || ' urowid;' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c' || c; 
          l_call := l_call || '~#'; 
        when l_desc_tab( c ).col_type = 8 then
          l_decl := l_decl || 'c' || c || ' varchar2(32760);' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c' || c; 
          l_call := l_call || '~#'; 
        when l_desc_tab( c ).col_type = 24 then
          l_decl := l_decl || 'c' || c || ' raw(2000);' || chr(10);
          l_call := l_call || '~~' || l_desc_tab( c ).col_name || '~!c' || c; 
          l_call := l_call || '~#'; 
        when l_desc_tab( c ).col_type = 114 then
          l_decl := l_decl || 'c' || c || ' bfile;' || chr(10);
        when l_desc_tab( c ).col_type = 109 then
          l_decl := l_decl || 'c' || c || ' ' || l_desc_tab( c ).col_schema_name || '.' || l_desc_tab( c ).col_type_name || ';' || chr(10);
          if (   l_desc_tab( c ).col_schema_name = 'SYS'
             and l_desc_tab( c ).col_type_name = 'XMLTYPE'
             )
          then
            l_call := l_call || 'PCK_JSON_UTIL.add_member(ro,q''^' || l_desc_tab( c ).col_name || '^'',PCK_JSON_UTIL.json(c' || c || '));' || chr(10);
          elsif (   l_desc_tab( c ).col_schema_name = 'SYS'
             and l_desc_tab( c ).col_type_name = 'ANYDATA'
             )
          then
            l_call := l_call || 'PCK_JSON_UTIL.add_member(ro,q''^' || l_desc_tab( c ).col_name || '^'',PCK_JSON_UTIL.json(c' || c || ',:pdf,:pr,:pb));' || chr(10);
          else
            l_call := l_call || 'PCK_JSON_UTIL.add_member(ro,q''^' || l_desc_tab( c ).col_name || '^'',PCK_JSON_UTIL.json(';
            begin
              execute immediate 'declare
  xx ' || l_desc_tab( c ).col_schema_name || '.' || l_desc_tab( c ).col_type_name || ';
  ad anydata;
begin
  ad := anydata.convertobject( xx );
end;';
              l_call := l_call || 'anydata.convertobject(c' || c || ')';
            exception when others then
              l_call := l_call || 'anydata.convertcollection(c' || c || ')';
            end;
            l_call := l_call || ',:pdf,:pr,:pb));' || chr(10);            
          end if; 
        when l_desc_tab( c ).col_type = 102 then
          l_decl := l_decl || 'c' || c || ' sys_refcursor;' || chr(10);
          if l_desc_tab( c ).col_name like p_return_object_pre || '%'
          then
            l_call := l_call || '~~' || substr( l_desc_tab( c ).col_name, length( p_return_object_pre ) + 1 ); 
            l_call := l_call || '^'',PCK_JSON_UTIL.json_ec(c' || c || ',:pdf,:pr,:pb,:cb,''Y'',' || '''' || p_return_object_pre || '''~#';
          else  
            l_call := l_call || '~~' || l_desc_tab( c ).col_name; 
            l_call := l_call || '^'',PCK_JSON_UTIL.json_ec(c' || c || ',:pdf,:pr,:pb,:cb,null,' || '''' || p_return_object_pre || '''~#';
          end if; 
        else
          raise_application_error( -20001, 'Unhandled type: ' || l_desc_tab( c ).col_type );
      end case;
      l_fetch := l_fetch || ',c' || c;
    end loop;
    l_call := replace( l_call, '~~', 'PCK_JSON_UTIL.add_member(ro,q''^' ); 
    l_call := replace( l_call, '~!', '^'',PCK_JSON_UTIL.jv(' ); 
    l_call := replace( l_call, '~#', '));' || chr(10) ); 
    l_decl := ltrim( l_decl, ',' );
    l_fetch := substr( l_fetch, 2 );
    p_rc := dbms_sql.to_refcursor( l_c );
    l_decl := 'declare
' || l_decl ||
'rc sys_refcursor;
ro PCK_JSON_UTIL.tp_json_value;
rv PCK_JSON_UTIL.tp_json_value;
df varchar2(2000);
pr pls_integer;
l_ad anydata;
begin
  rc := :rc;
  rv.json_type := ''A'';
  rv.idx := :idx;
  df := :pdf;
  df := :tsf;
  pr := :pr;
  pr := :pb;  
  df := :cb;';
    if p_return_object = 'Y'
    then
      l_call := '        ro.json_type := ''O'';
        ro.idx := rv.idx;
' || l_call || '    exit;';
    else
      l_call := '    ro := PCK_JSON_UTIL.json( '''' ); -- empty object
' || l_call || '    PCK_JSON_UTIL.add_item( rv, ro );';
    end if;
    execute immediate l_decl || '
  loop
    fetch rc into ' || l_fetch || '; 
    exit when rc%notfound;
' || l_call || '
  end loop;
end;' using in out p_rc, l_rv.idx, p_date_fmt, 'yyyy.mm.dd hh24:mi:ssxff'
                 , p_raw, p_blob, p_check_boolean_strings;  
    return l_rv;
$END
  end;
--
  function get_json_type( p_val tp_json_value )
  return varchar2
  is
  begin
    return case p_val.json_type
             when 'V' then 'STRING'
             when 'v' then 'STRING'
             when 'C' then 'STRING'
             when 'c' then 'STRING'
             when 'N' then 'NUMBER'
             when 'B' then 'BOOLEAN'
             when 'O' then 'OBJECT'
             when 'A' then 'ARRAY'
             when 'E' then 'NULL'
           end;
  end;
--
  function get_string
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs
    , p_charset varchar2 character set any_cs := null  -- set charset of result
    )
  return varchar2 character set p_charset%charset
  is
    t_val tp_json_value;
  begin
    if p_path is null
    then
      t_val := p_val;
    else
      t_val := path_get( p_val, p_path );
    end if;
    if t_val.json_type = 'V'
      then return g_vstrings( t_val.idx );
    elsif t_val.json_type = 'v'
      then return g_nstrings( t_val.idx );
    elsif t_val.json_type = 'N'
      then return g_numbers( t_val.idx );
    elsif t_val.json_type = 'C'
      then return g_clobs( t_val.idx );
    elsif t_val.json_type is not null
      then return vstringify( t_val );
    else
      return null;
    end if;
  end;
--
  function get_string_clob
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs
    , p_charset varchar2 character set any_cs := null  -- set charset of result
    )
  return clob character set p_charset%charset
  is
    t_val tp_json_value;
  begin
    if p_path is null
    then
      t_val := p_val;
    else
      t_val := path_get( p_val, p_path );
    end if;
    if t_val.json_type = 'V'
      then return g_vstrings( t_val.idx );
    elsif t_val.json_type = 'v'
      then return g_nstrings( t_val.idx );
    elsif t_val.json_type = 'N'
      then return to_char( g_numbers( t_val.idx ) );
    elsif t_val.json_type = 'C'
      then return g_clobs( t_val.idx );
    elsif t_val.json_type is not null
      then return stringify( t_val );
    else
      return null;
    end if;
  end;
--
  function get_number
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs
    )
  return number
  is
    t_val tp_json_value;
  begin
    if p_path is null
    then
      t_val := p_val;
    else
      t_val := path_get( p_val, p_path );
    end if;
    return case t_val.json_type
             when 'N' then g_numbers( t_val.idx )
           end;
  end;
--
  function get_boolean
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs
    )
  return boolean
  is
    t_val tp_json_value;
  begin
    if p_path is null
    then
      t_val := p_val;
    else
      t_val := path_get( p_val, p_path );
    end if;
    return case t_val.json_type
             when 'B' then t_val.idx = 1
           end;
  end;
--
  function get_date
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs
    , p_fmt varchar2 := null
    )
  return date
  is
    t_val tp_json_value;
    t_fmt varchar2(3999);
    t_rv date;
    t_tzh number;
  begin
    if p_path is null
    then
      t_val := p_val;
    else
      t_val := path_get( p_val, p_path );
    end if;
    if t_val.json_type = 'V'
    then
      t_fmt := coalesce( p_fmt, g_date_fmt, c_date_iso8601 );
      t_rv := to_date( g_vstrings( t_val.idx ), t_fmt );
      if t_fmt = c_date_iso8601
      then
-- check for c_date_iso8601 and convert from UTC, the Z means Zulu = Zero, i.e. use UTC+0:00
        t_tzh := extract( TIMEZONE_HOUR from current_timestamp );
        t_tzh := t_tzh + sign( t_tzh ) * extract( TIMEZONE_MINUTE from current_timestamp ) / 60;
        t_rv := t_rv + t_tzh / 24;
      end if;
    end if;
    return t_rv;
  end;
--
  function get_count( p_val tp_json_value )
  return pls_integer
  is
  begin
    return case
             when p_val.json_type = 'O'
               then trunc( g_json( p_val.idx ).count / 2 )
             when p_val.json_type = 'A'
               then g_json( p_val.idx ).count - 1
           end;
  end;
--
  function get_name( p_val tp_json_value, p_idx pls_integer )
  return varchar2
  is
  begin
    if p_val.json_type = 'O' and g_json( p_val.idx ).exists( p_idx * 2 - 1 )
    then
      return get_string( g_json( p_val.idx )( p_idx * 2 - 1 ) );
    else
      return null;
    end if;
  end;
--
  function get_value( p_val tp_json_value, p_idx pls_integer )
  return tp_json_value
  is
  begin
    if p_val.json_type = 'O' and g_json( p_val.idx ).exists( p_idx * 2 )
    then
      return g_json( p_val.idx )( p_idx * 2 );
    elsif p_val.json_type = 'A' and g_json( p_val.idx ).exists( p_idx )
    then
      return g_json( p_val.idx )( p_idx );
    else
      return null;
    end if;
  end;
--
  function path_get
    ( p_val tp_json_value
    , p_path varchar2 character set any_cs
    )
  return tp_json_value
  is
    l_idx number;
    l_pos pls_integer;
    l_jv tp_json_value;
    l_jv2 tp_json_value;
    l_tmp varchar2(1 char) character set p_path%charset;
    l_name varchar2(32767) character set p_path%charset;
    l_path varchar2(32767) character set p_path%charset;
    c_sp  constant varchar2(1 char) character set p_path%charset := ' ';       -- space
    c_dq  constant varchar2(1 char) character set p_path%charset := '"';       -- double quote
    c_bsl constant varchar2(1 char) character set p_path%charset := '\';       -- back slash
    c_u   constant varchar2(1 char) character set p_path%charset := 'u';       -- u
    c_sbo constant varchar2(1 char) character set p_path%charset := '[';       -- square bracket, open
    c_sbc constant varchar2(1 char) character set p_path%charset := ']';       -- square bracket, close
    c_per constant varchar2(1 char) character set p_path%charset := '.';       -- period
    c_wc  constant varchar2(1 char) character set p_path%charset := '*';       -- wildcard
  begin
    l_path := rtrim( p_path );
    l_path := ltrim( l_path, c_per || c_sp );
    if l_path is null
    then
      return p_val;
    end if;
    if (  ( substr( l_path, 1, 1 ) = c_wc and p_val.json_type = 'O' )
       or (   substr( l_path, 1, 3 ) = c_sbo || c_wc || c_sbc
          and p_val.json_type in ( 'A', 'O' )
          )
       )
    then
      l_path := case when substr( l_path, 1, 1 ) = c_wc
                  then substr( l_path, 2 )
                  else substr( l_path, 4 )
                end;
      for i in 1 .. get_count( p_val )
      loop
        l_jv2 := path_get( get_value( p_val, i ), l_path );
        if l_jv2.json_type is not null
        then
          add_item( l_jv, l_jv2 );
        end if;
      end loop;
    elsif substr( l_path, 1, 1 ) = c_sbo
    then
      l_pos := instr( l_path, c_sbc );
      if l_pos > 0
      then
        l_jv := path_get( get_value( p_val, substr( l_path, 2, l_pos - 2 ) )
                        , substr( l_path, l_pos + 1 )
                        );
      end if;
    elsif p_val.json_type = 'O'
    then
      if substr( l_path, 1, 1 ) = c_dq
      then
        l_pos := 2;
        loop
          l_tmp := substr( l_path, l_pos, 1 );
          if l_tmp = c_bsl
          then
            l_pos := l_pos + 1;
            l_tmp := substr( l_path, l_pos, 1 );
            if l_tmp = c_u
            then
              l_tmp := unistr( c_bsl || substr( l_path, l_pos + 1, 4 ) );
              l_pos := l_pos + 4;
            else
              l_tmp := translate( l_tmp
                                , 'bfnrt'
                                , chr( 8 ) || chr( 12 ) || chr( 10 ) || chr( 13 ) || chr( 9 )
                                );
            end if;
          else
            exit when l_tmp = c_dq;
          end if;
          if l_tmp is null
          then
            return null;
          end if;
          l_pos := l_pos + 1;
          l_name := l_name || l_tmp;
        end loop;
        l_pos := l_pos + 1;
      else
        l_pos := least( nvl( nullif( instr( l_path, c_sbo ), 0 ), 32767 )
                      , nvl( nullif( instr( l_path, c_per ), 0 ), 32767 )
                      );
        l_name := substr( l_path, 1, l_pos - 1 );
      end if;
      for i in 1 .. get_count( p_val )
      loop
        if get_name( p_val, i ) = l_name
        then
          if l_pos < 32767
          then
            l_jv := path_get( get_value( p_val, i ), substr( l_path, l_pos ) );
          else
            l_jv := get_value( p_val, i );
          end if;
          exit;
        end if;
      end loop;
    end if;
    return l_jv;
  end;
--
  procedure free
  is
  begin
    g_numbers.delete;
    g_vstrings.delete;
    g_nstrings.delete;
    for i in 0 .. g_clobs.count - 1
    loop
      dbms_lob.freetemporary( g_clobs( i ) );
    end loop;
    g_clobs.delete;
    for i in 0 .. g_json.count - 1
    loop
      g_json(i).delete;
    end loop;
    g_json.delete;
  end;
--
  procedure free( p_val tp_json_value )
  is
  begin
    if p_val.json_type in ( 'A', 'O' )
    then
      for i in 1 .. g_json( p_val.idx ).count - 1
      loop
        free( g_json( p_val.idx )( i ) );
      end loop;
      g_json( p_val.idx ).delete;
    elsif p_val.json_type in ( 'C' )
    then
      dbms_lob.freetemporary( g_clobs( p_val.idx ) );
    end if;
  end;
--
  function escape_json( p_val varchar2 character set any_cs )
  return varchar2
  is
  begin
    return replace(
           replace(
           replace(
           replace(
           replace(
           replace(
           replace(
           replace(
           replace( asciistr( p_val )
                  , '\', '\u' )
                  , '"', '\"' )
                  , '\u005C', '\\' )
                  , '/', '\/' )
                  , chr(8), '\b' )
                  , chr(12), '\f' )
                  , chr(10), '\n' )
                  , chr(13), '\r' )
                  , chr(9), '\t' );
  end;
--
  function escape_cjson( p_val clob character set any_cs )
  return clob
  is
  begin
    return replace(
           replace(
           replace(
           replace(
           replace(
           replace(
           replace(
           replace(
           replace( p_val
                  , '\', '\u' )
                  , '"', '\"' )
                  , '\u005C', '\\' )
                  , '/', '\/' )
                  , chr(8), '\b' )
                  , chr(12), '\f' )
                  , chr(10), '\n' )
                  , chr(13), '\r' )
                  , chr(9), '\t' );
  end;
--
  function nstringify( p_val number )
  return varchar2
  is
    t_rv varchar2(3999) := to_char( p_val, 'TM9', 'NLS_NUMERIC_CHARACTERS=.,' );
  begin
    if substr( t_rv, 1, 1 ) = '.'
    then
      t_rv := '0' || t_rv;
    elsif substr( t_rv, 1, 2 ) = '-.'
    then
      t_rv := '-0' || substr( t_rv, 2 );
    end if;
    return t_rv;
  end;
--
  function vstringify( p_val tp_json_value
                     , p_inc pls_integer := null -- pretty print increment
                     , p_xxx pls_integer := null -- # spaces after colon
                     , p_ind pls_integer := null -- pretty print current indent
                     )
  return varchar2
  is
    t_ind pls_integer := nvl( p_ind, 0 ) + p_inc;
    t_rv varchar2(32767);
  begin
    case p_val.json_type
      when 'O'
      then
        t_rv := ( '{' || case when p_inc is not null and g_json( p_val.idx ).count > 1 then chr(10) end );
        for i in 1 .. g_json( p_val.idx ).count - 1
        loop
          if mod( i, 2 ) = 1
          then
            t_rv := t_rv || (  case when i > 2 then ',' || case when p_inc is not null then chr(10) end end
                            || rpad( ' ', t_ind )
                            || vstringify( g_json( p_val.idx )(i) )
                            );
          else
            t_rv := t_rv || (  rpad( ':', nvl( p_xxx, 0 ) + 1 )
                            || vstringify( g_json( p_val.idx )(i), p_inc, p_xxx, t_ind )
                            );
          end if;
        end loop;
        t_rv := t_rv || ( rpad( chr(10), t_ind - 1 ) || '}' );
        return t_rv;
      when 'A'
      then
        dbms_lob.createtemporary( t_rv, true, dbms_lob.call );
        t_rv := ( '[' || case when p_inc is not null and g_json( p_val.idx ).count > 1 then chr(10) end );
        for i in 1 .. g_json( p_val.idx ).count - 1
        loop
          t_rv := t_rv || (  case when i > 1 then ',' || case when p_inc is not null then chr(10) end end
                          || rpad( ' ', t_ind )
                          || vstringify( g_json( p_val.idx )(i), p_inc, p_xxx, t_ind )
                          );
        end loop;
        t_rv := t_rv || ( rpad( chr(10), t_ind - 1 ) || ']' );
        return t_rv;
      when 'V' then return '"' || escape_json( g_vstrings( p_val.idx ) ) || '"';
      when 'N' then return nstringify( g_numbers( p_val.idx ) );
      when 'B' then return case when p_val.idx = 1 then 'true' else 'false' end;
      when 'E' then return 'null';
      when 'C' then return '"' || escape_cjson( g_clobs( p_val.idx ) ) || '"';
      when 'v' then return '"' || escape_json( g_nstrings( p_val.idx ) ) || '"';
      when 'c' then return '"' || escape_json( g_nstrings( p_val.idx ) ) || '"';
      else return null;
    end case;
  end;
--
  function stringify( p_val tp_json_value
                    , p_inc pls_integer := null -- pretty print increment
                    , p_xxx pls_integer := null -- # spaces after colon
                    , p_ind pls_integer := null -- pretty print current indent
                    )
  return clob
  is
    t_ind pls_integer := nvl( p_ind, 0 ) + p_inc;
    t_rv clob;
  begin
    return vstringify( p_val, p_inc, p_xxx, p_ind );
  exception
    when others
    then
      case p_val.json_type
        when 'O'
        then
          dbms_lob.createtemporary( t_rv, true, dbms_lob.call );
          t_rv := ( '{' || case when p_inc is not null and g_json( p_val.idx ).count > 1 then chr(10) end );
          for i in 1 .. g_json( p_val.idx ).count - 1
          loop
            if mod( i, 2 ) = 1
            then
              t_rv := t_rv || (  case when i > 2 then ',' || case when p_inc is not null then chr(10) end end
                              || rpad( ' ', t_ind )
                              || stringify( g_json( p_val.idx )(i) )
                              );
            else
              t_rv := t_rv || (  rpad( ':', nvl( p_xxx, 0 ) + 1 )
                              || stringify( g_json( p_val.idx )(i), p_inc, p_xxx, t_ind )
                              );
            end if;
          end loop;
          t_rv := t_rv || ( rpad( chr(10), t_ind - 1 ) || '}' );
          return t_rv;
        when 'A'
        then
          dbms_lob.createtemporary( t_rv, true, dbms_lob.call );
          t_rv := ( '[' || case when p_inc is not null and g_json( p_val.idx ).count > 1 then chr(10) end );
          for i in 1 .. g_json( p_val.idx ).count - 1
          loop
            t_rv := t_rv || (  case when i > 1 then ',' || case when p_inc is not null then chr(10) end end
                            || rpad( ' ', t_ind )
                            || stringify( g_json( p_val.idx )(i), p_inc, p_xxx, t_ind )
                            );
          end loop;
          t_rv := t_rv || ( rpad( chr(10), t_ind - 1 ) || ']' );
          return t_rv;
        when 'V' then return '"' || escape_json( g_vstrings( p_val.idx ) ) || '"';
        when 'N' then return nstringify( g_numbers( p_val.idx ) );
        when 'B' then return case when p_val.idx = 1 then 'true' else 'false' end;
        when 'E' then return 'null';
        when 'C' then return '"' || escape_cjson( g_clobs( p_val.idx ) ) || '"';
        when 'v' then return '"' || escape_json( g_nstrings( p_val.idx ) ) || '"';
        when 'c' then return '"' || escape_json( g_nstrings( p_val.idx ) ) || '"';
        else return null;
      end case;
  end;
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
  return clob
  is
    l_jv tp_json_value;
    l_rv clob;
  begin
    l_jv := json( p_rc, p_date_fmt, p_raw, p_blob, p_check_boolean_strings = 'Y' );
    l_rv := stringify( l_jv );
    free;
    return l_rv;
  end;
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
  return clob
  is
    l_rc sys_refcursor := p_rc;
    l_jv tp_json_value;
    l_rv clob;
  begin
    l_jv := json_ec( l_rc, p_date_fmt, p_raw, p_blob, p_check_boolean_strings, p_return_object, p_return_object_pre );
    l_rv := stringify( l_jv );
    free;
    return l_rv;
  end;
--
  procedure htp( p_val tp_json_value
               , p_add_json_header boolean := true
               , p_jsonp varchar2 := null
               , p_free boolean := true
               )
  is
    l_tmp clob;
  begin
    sys.htp.init;
    if p_add_json_header
    then
      if p_jsonp is null
      then
        owa_util.mime_header( 'application/json', false );
      else
        owa_util.mime_header( 'application/javascript', false );
      end if;
      sys.htp.p( 'Cache-Control: no-store, no-cache, must-revalidate' );
      owa_util.http_header_close;
    end if;
    if p_jsonp is not null
    then
      sys.htp.prn( p_jsonp || '(' );
    end if;
    begin
      sys.htp.prn( vstringify( p_val ) );
    exception
      when others
      then
        l_tmp := stringify( p_val );
        for i in 0 .. trunc( ( dbms_lob.getlength( l_tmp ) - 1 ) / 32767 )
        loop
          sys.htp.prn( dbms_lob.substr( l_tmp, 32767, i * 32767 + 1 ) );
        end loop;
      dbms_lob.freetemporary( l_tmp );
    end;
    if p_jsonp is not null
    then
      sys.htp.prn( ');' );
    end if;
    if p_free
    then
      free;
    end if;
  end;
--
  function to_xmltype
    ( p_val tp_json_value
    , p_root varchar2 := null
    , p_array_item varchar2 := null
    , p_free varchar2 := 'Y'
    )
  return xmltype
  is
    l_rv xmltype;
    l_doc dbms_xmldom.domdocument;
    l_nd dbms_xmldom.domnode;
    l_root dbms_xmldom.domnode;
--
    function add_element( p_nd dbms_xmldom.domnode, p_tag varchar2 )
    return dbms_xmldom.domnode
    is
    begin
      return dbms_xmldom.appendchild( p_nd, dbms_xmldom.makenode( dbms_xmldom.createelement( l_doc, p_tag ) ) );
    end;
--
    function add_text( p_nd dbms_xmldom.domnode, p_text varchar2 )
    return dbms_xmldom.domnode
    is
    begin
      return dbms_xmldom.appendchild( p_nd, dbms_xmldom.makenode( dbms_xmldom.createtextnode( l_doc, p_text ) ) );
    end;
--
    function x( p_val tp_json_value, p_nd dbms_xmldom.domnode )
    return dbms_xmldom.domnode
    is
      l_nd dbms_xmldom.domnode;
    begin
      case p_val.json_type
        when 'O'
        then
          for i in 1 .. g_json( p_val.idx ).count - 1
          loop
            if mod( i, 2 ) = 1
            then
              l_nd := add_element( p_nd, g_vstrings( g_json( p_val.idx )(i).idx ) );
            else
              l_nd := x( g_json( p_val.idx )(i), l_nd );
            end if;
          end loop;
        when 'A'
        then
          for i in 1 .. g_json( p_val.idx ).count - 1
          loop
            l_nd := add_element( p_nd, nvl( p_array_item, 'row' ) );
            l_nd := x( g_json( p_val.idx )(i), l_nd );
          end loop;
        when 'V' then l_nd := add_text( p_nd, g_vstrings( p_val.idx ) );
        when 'N' then l_nd := add_text( p_nd, nstringify( g_numbers( p_val.idx ) ) );
        when 'B' then l_nd := add_text( p_nd, case when p_val.idx = 1 then 'true' else 'false' end );
        when 'E' then l_nd := add_text( p_nd, 'null' );
        when 'C' then l_nd := add_text( p_nd, g_clobs( p_val.idx ) );
        when 'v' then l_nd := add_text( p_nd, g_nstrings( p_val.idx ) );
        when 'c' then l_nd := add_text( p_nd, g_nstrings( p_val.idx ) );
      end case;
      return l_nd;
    end;
  begin
    if p_val.json_type is not null
    then
      l_doc := dbms_xmldom.newdomdocument;
      dbms_xmldom.setVersion( l_doc, '1.0' );
      l_root := dbms_xmldom.makenode( l_doc );
      l_nd := x( p_val, add_element( l_root, nvl( p_root, 'json' ) ) );
      l_rv := dbms_xmldom.getxmltype( l_doc );
      dbms_xmldom.freedocument( l_doc );
      if upper( p_free ) in ( 'Y', 'J', 'T', 'TRUE' )
      then
        free;
      end if;
    end if;
    return l_rv;
  end;
--
  function to_xmltype
    ( p_json clob character set any_cs
    , p_root varchar2 := null
    , p_array_item varchar2 := null
    , p_free varchar2 := 'Y'
    )
  return xmltype
  is
  begin
    return to_xmltype( json( p_json => p_json ), p_root, p_array_item, p_free );
  end;
--
  procedure set_default_date_fmt( p_fmt varchar2 )
  is
  begin
    g_date_fmt := p_fmt;
  end;
--
-- ***********
--
  function jvi( p_val tp_json_value )
  return number
  is
  begin
    return p_val.idx + case p_val.json_type                  
                         when 'O' then 4294967296
                         when 'V' then 8589934592
                         when 'N' then 17179869184
                         when 'A' then 34359738368
                         when 'C' then 68719476736
                         when 'B' then 137438953472
                         when 'E' then 274877906944
                         when 'v' then 549755813888
                         when 'c' then 1099511627776
                       end;
  end;
--
  function ijv( p_idx number )
  return  tp_json_value
  is
    t_rv  tp_json_value;
  begin
    t_rv.idx := bitand( p_idx, 4294967295 );
    t_rv.json_type := case bitand( p_idx, 4393751543808 )
                        when 4294967296    then 'O'
                        when 8589934592    then 'V'
                        when 17179869184   then 'N'
                        when 34359738368   then 'A'
                        when 68719476736   then 'C'
                        when 137438953472  then 'B'
                        when 274877906944  then 'E'
                        when 549755813888  then 'v'
                        when 1099511627776 then 'c'
                      end;
    return t_rv;
  end;
--
  function qjson( p_json clob character set any_cs ) -- parses a JSON-string
  return number
  is
  begin
    return jvi( json( p_json ) );
  end;
--
  function qget_string
    ( p_val number
    , p_path varchar2 character set any_cs := null
    , p_charset varchar2 character set any_cs := null  -- set charset of result
    )
  return varchar2 character set p_charset%charset
  is
  begin
    return get_string( ijv( p_val ), p_path, p_charset );
  end;
--
  function qget_string_clob
    ( p_val number
    , p_path varchar2 character set any_cs := null
    , p_charset varchar2 character set any_cs := null  -- set charset of result
    )
  return clob character set p_charset%charset
  is
  begin
    return get_string_clob( ijv( p_val ), p_path, p_charset );
  end;
--
  function qget_number
    ( p_val number
    , p_path varchar2 character set any_cs := null
    )
  return number
  is
  begin
    return get_number( ijv( p_val ), p_path );
  end;
--
  function qget_boolean
    ( p_val number
    , p_path varchar2 character set any_cs
    , p_true varchar2 := 'TRUE'
    , p_false varchar2 := 'FALSE'
    )
  return varchar2
  is
  begin
    return case when get_boolean( ijv( p_val ), p_path )
             then p_true
             else p_false
           end;
  end;
--
  function qget_date
    ( p_val number
    , p_path varchar2 character set any_cs := null
    , p_fmt varchar2 := null
    )
  return date
  is
  begin
    return get_date( ijv( p_val ), p_path, p_fmt );
  end;
--
  function qpath_get
    ( p_val number
    , p_path varchar2 character set any_cs
    )
  return number
  is
  begin
    return jvi( path_get( ijv( p_val ), p_path ) );
  end;
--
  function qget_array
    ( p_val number
    , p_path varchar2 character set any_cs := null
    )
  return tp_jv_indexes pipelined
  is
    t_val tp_json_value;
  begin
    t_val := path_get( ijv( p_val ), p_path );
    if t_val.json_type = 'A'
    then
      for i in 1 .. get_count( t_val )
      loop
        pipe row( jvi( get_value( t_val, i ) ) );
      end loop;
    end if;
  end;
end;
/