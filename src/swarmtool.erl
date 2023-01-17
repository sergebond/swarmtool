-module(swarmtool).
-author("serhiibondarchuk").

%% API
-export([
  login_by_userid_and_pwd/2,
  login_by_jwe/1,
  login_by_userid_and_auth_token/2,
  login_by_auth_token_and_jwe_token/2,
  auth/1]).

%% swarmtool:auth(#{<<"username">> => <<"viacheslav.borozenko@betconstruct.com">>, <<"password">> => <<"1234qazQaz">>}).
%% swarmtool:auth(#{<<"jwe_token">> => JweToken}}).
%% swarmtool:auth(#{<<"user_id">> => 318889366, <<"auth_token">> => <<"53763B9F3D9750C27352C88D5DF53D14">>}).
%% swarmtool:auth(#{<<"jwe_token">> => JweToken, <<"auth_token">> => AuthToken}}).

login_by_userid_and_pwd(UserId, Password) ->
  auth(#{<<"username">> => UserId, <<"password">> => Password}).

login_by_jwe(JweToken) ->
  auth(#{<<"jwe_token">> => JweToken}).

login_by_userid_and_auth_token(UserId, AuthToken) ->
  auth(#{<<"user_id">> => UserId, <<"auth_token">> => AuthToken}).

login_by_auth_token_and_jwe_token(JweToken, AuthToken) ->
  auth(#{<<"jwe_token">> => JweToken, <<"auth_token">> => AuthToken}).

auth(Args) when is_map(Args) ->
  swarmtool_auth_srv:call(Args).
