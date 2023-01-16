-module(swarmtool).
-author("serhiibondarchuk").

%% API
-export([auth/1]).

%% swarmtool:auth(#{<<"username">> => <<"viacheslav.borozenko@betconstruct.com">>, <<"password">> => <<"1234qazQaz">>}).
%% swarmtool:auth(#{<<"jwe_token">> => JweToken}}).
%% swarmtool:auth(#{<<"user_id">> => 318889366, <<"auth_token">> => <<"53763B9F3D9750C27352C88D5DF53D14">>}).
%% swarmtool:auth(#{<<"jwe_token">> => JweToken, <<"auth_token">> => AuthToken}}).

auth(Args) when is_map(Args) ->
  swarmtool_auth_srv:call(Args).
