-ifndef(ALLINN_AUTH_COMMON_HRL).
-define(ALLINN_AUTH_COMMON_HRL, true).

-define(APP_NAME, swarmtool).
-define(POOL_NAME, ?APP_NAME).

-define(JSON_LIB, jsx).

-ifdef(JSON_LIB).

  -if(?JSON_LIB =:= jsx).
    -define(JSON_ENCODE(Term), jsx:encode(Term)).
    -define(JSON_DECODE(Json), jsx:decode(Json, [return_maps])).
  -elif(?JSON_LIB =:= jiffy).
    -define(JSON_ENCODE(Term), jiffy:encode(Term)).
    -define(JSON_DECODE(Json), jiffy:decode(Json, [return_maps])).
  -elif(?JSON_LIB =:= jsone).
    -define(JSON_ENCODE(Term), jsone:encode(Term)).
    -define(JSON_DECODE(Json), jsone:decode(Json, [{object_format, map}])).
  -endif.
-endif.

-define(UUIDv4BinStr, uuid:uuid_to_string(uuid:get_v4(strong), binary_standard)).


-endif.
