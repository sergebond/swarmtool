-module(swarmtool_auth_srv).

-behaviour(gen_server).

%% API
-export([
  call/1,
  cast/1
]).

%% API
-export([
  get_user_id/1,
  get_user_profile/1
]).

%% API
-export([
  swarm_error/1
]).

-export([
  start_link/0,
  start_link/1
]).

%% Callbacks
-export([
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  handle_continue/2,
  terminate/2,
  code_change/3
]).

-include_lib("kernel/include/logger.hrl").
-include("swarmtool_auth.hrl").
-include("swarmtool.hrl").

-define(SERVER, ?MODULE).

%-define(DEBUG, true).

-ifdef(DEBUG).
-define(GEN_SERVER_OPTS, [{debug, [trace, {log_to_file, "log/debug.log"}]}]).
-else.
-define(GEN_SERVER_OPTS, []).
-endif.


-define(WORKER_CALL_STRATEGY, available_worker).
-define(WORKER_CALL_TIMEOUT, 30000).


-record(state, {
  host :: inet:hostname() | inet:ip_address(),
  port :: inet:port_number(),
  path :: iodata(),
  ws_open_timeout :: infinity | pos_integer(),
  ws_pid :: pid(),
  ws_await_up_timeout :: infinity | pos_integer(),
  ws_await_timeout :: infinity | pos_integer(),
  ws_upgrade_timeout :: infinity | pos_integer(),
  stream_ref :: gun:stream_ref()
}).

%%% ==================================================================
%%% API functions
%%% ==================================================================

%% swarmtool_auth_srv:call(#{<<"username">> => <<"viacheslav.borozenko@betconstruct.com">>, <<"password">> => <<"1234qazQaz">>}).
%% swarmtool_auth_srv:call(#{<<"jwe_token">> => JweToken}}).
%% swarmtool_auth_srv:call(#{<<"user_id">> => 318889366, <<"auth_token">> => <<"53763B9F3D9750C27352C88D5DF53D14">>}).
%% swarmtool_auth_srv:call(#{<<"jwe_token">> => JweToken, <<"auth_token">> => AuthToken}}).
%% swarmtool_auth_srv:get_user_profile(#{<<"username">> => <<"viacheslav.borozenko@betconstruct.com">>, <<"password">> => <<"1234qazQaz">>}).
-spec call(maps:map()) -> term().
call(Call) ->
  poolboy:transaction(?POOL_NAME, fun(Worker) -> gen_server:call(Worker, Call) end, ?WORKER_CALL_TIMEOUT).

-spec cast(maps:map()) -> term().
cast(Cast) ->
  poolboy:transaction(?POOL_NAME, fun(Worker) -> gen_server:cast(Worker, Cast) end).

-spec get_user_id(maps:map()) -> {ok, integer()} | {error, term()}.
get_user_id(Credentials) ->
  case get_user_profile(Credentials) of
    {ok, #{<<"user_id">> := UserId}} ->
      {ok, UserId};
    {error, Reason} ->
      {error, Reason}
  end.

-spec get_user_profile(maps:map()) -> {ok, maps:map()} | {error, term()}.
get_user_profile(Credentials) ->
  case catch call(Credentials) of
    {ok, #{<<"code">> := 0, <<"data">> := Data}} ->
      {ok, Data};
    {ok, #{<<"code">> := Code}} ->
      swarm_error(Code);
    {error, Reason} ->
      {error, Reason};
    {'EXIT', {timeout, _}} ->
      {error, timeout}
  end.

%% -------------------------------------------------------------------
%% @doc
%% Starts the server.
%% @end
%% -------------------------------------------------------------------
-spec start_link() ->
  {ok, Pid :: pid()}
  | ignore
  | {error, Reason :: term()}.

start_link() ->
  start_link([]).

%% -------------------------------------------------------------------
%% @doc
%% Starts the server.
%% @end
%% -------------------------------------------------------------------
-spec start_link(Args :: term()) ->
  {ok, Pid :: pid()}
  | ignore
  | {error, Reason :: term()}.

start_link(Args) ->
  gen_server:start_link(?SERVER, Args, ?GEN_SERVER_OPTS).

%%% ==================================================================
%%% Callback functions
%%% ==================================================================

%% @hidden
-spec init(Args :: term()) ->
  {ok, State :: term()}
  | {ok, State :: term(), timeout() | hibernate | {continue, term()}}
  | {stop, Reason :: term()}
  | ignore.

init(Opts) ->
  {Host, Port} = host_info(),
  {ok, #state{host = Host,
              port = Port,
              path = proplists:get_value(path, Opts, "/"),
              ws_open_timeout     = proplists:get_value(ws_open_timeout, Opts, 15),
              ws_await_up_timeout = proplists:get_value(ws_await_up_timeout, Opts, 15),
              ws_await_timeout    = proplists:get_value(ws_await_timeout, Opts, 15),
              ws_upgrade_timeout  = proplists:get_value(ws_upgrade_timeout, Opts, 15)},
      {continue, ws_open}}.

%% @hidden
-spec handle_call(Request :: term(), From :: {pid(), Tag :: term()}, State :: term()) ->
  {reply, Reply :: term(), NewState :: term()}
  | {reply, Reply :: term(), NewState :: term(), timeout() | hibernate | {continue, term()}}
  | {noreply, NewState :: term()}
  | {noreply, NewState :: term(), timeout() | hibernate | {continue, term()}}
  | {stop, Reason :: term(), Reply :: term(), NewState :: term()}
  | {stop, Reason :: term(), NewState :: term()}.

handle_call(Call, _From, #state{ws_pid = Pid, stream_ref = Ref} = State) when is_map(Call) ->
  ReqSeq = prepare_req_seq(Call),
  Reply = send_req_seq({Pid, Ref}, ReqSeq),
  {reply, Reply, State};

handle_call(_Req, _From, State) ->
  {reply, ok, State}.

%% @hidden
-spec handle_cast(Request :: term(), State :: term()) ->
  {noreply, NewState :: term()}
  | {noreply, NewState :: term(), timeout() | hibernate | {continue, term()}}
  | {stop, Reason :: term(), NewState :: term()}.

handle_cast(Req, #state{ws_pid = Pid, stream_ref = Ref} = State) when is_map(Req) ->
  ok = ws_send(Pid, Ref, Req),
  {noreply, State};

handle_cast(_Req, State) ->
  {noreply, State}.

%% @hidden
-spec handle_info(Info :: timeout | term(), State :: term()) ->
  {noreply, NewState :: term()}
  | {noreply, NewState :: term(), timeout() | hibernate | {continue, term()}}
  | {stop, Reason :: term(), NewState :: term()}.

handle_info({gun_down, Pid, _Proto, _Reason, _KilledStreams}, State) ->
  ok = gun:shutdown(Pid),
  ok = gun:flush(Pid),
  {noreply, State#state{ws_pid = undefined}, {continue, ws_open}};

handle_info({gun_error, ServerPid, StreamRef, _Reason}, State) ->
  ok = gun:shutdown(ServerPid),
  ok = gun:flush(ServerPid),
  ok = gun:flush(StreamRef),
  {noreply, State#state{ws_pid = undefined}, {continue, ws_open}};

handle_info({gun_error, ServerPid, _Reason}, State) ->
  ok = gun:shutdown(ServerPid),
  ok = gun:flush(ServerPid),
  {noreply, State#state{ws_pid = undefined}, {continue, ws_open}};

handle_info({gun_ws, ConnPid, StreamRef, {close, _Code, _Message}}, State) ->
  ok = gun:shutdown(ConnPid),
  ok = gun:flush(ConnPid),
  ok = gun:flush(StreamRef),
  {noreply, State#state{ws_pid = undefined}, {continue, ws_open}};

handle_info({gun_ws, _ConnPid, _StreamRef, _Frame}, State) ->
  {noreply, State};

handle_info({'DOWN', MRef, process, ServerPid, _Reason}, State) ->
  ok = gun:shutdown(ServerPid),
  ok = gun:flush(ServerPid),
  ok = gun:flush(MRef),
  {noreply, State#state{ws_pid = undefined}, {continue, ws_open}};

handle_info(_Info, State) ->
  {noreply, State}.

%% @hidden
-spec handle_continue(Info :: term(), State :: term()) ->
  {noreply, NewState :: term()}
  | {noreply, NewState :: term(), timeout() | hibernate | {continue, term()}}
  | {stop, Reason :: term(), NewState :: term()}.

handle_continue(ws_open, #state{host = Host, port = Port, ws_open_timeout = Timeout} = State) ->
  Opts = #{
    connect_timeout => Timeout * 1000,
    ws_opts => #{
      reply_to => self(),
      keepalive => 5000
    },
    protocols => [http],
    tls_handshake_timeout => 5000,
    tls_opts => [
      {verify, verify_none}
%%      {verify, verify_peer},
%%      {cacertfile, "/etc/ssl/certs/ca-certificates.crt"}
    ],
    transport => tls,
    retry => 5,
    retry_timeout => 5000
    %retry_fun => fun reconnect/0
    %,trace => true
  },
  case gun:open(Host, Port, Opts) of
    {ok, Pid} ->
      Ref = monitor(process, Pid),
      {noreply, State#state{ws_pid = Pid, stream_ref = Ref}, {continue, ws_await_up}};
    {error, Reason} ->
      ?LOG_ERROR("ws_open FAILED. Reason = ~p", [Reason]),
      timer:sleep(1000), % TODO: RetryAfter
      {noreply, State, {continue, ws_open}}
  end;

handle_continue(ws_await_up, #state{ws_pid = Pid, ws_await_up_timeout = Timeout} = State) ->
  case gun:await_up(Pid, Timeout * 1000) of
    {ok, _Protocol} ->
      {noreply, State, {continue, ws_upgrade}};
    {error, Reason} ->
      ?LOG_ERROR("ws_await_up FAILED. Reason = ~p", [Reason]),
      {stop, Reason, State}
  end;

handle_continue(ws_upgrade, #state{ws_pid = Pid, path = Path} = State) ->
  Headers = [],
  StreamRef = gun:ws_upgrade(Pid, Path, Headers), % TODO: reply_to
  {noreply, State#state{stream_ref = StreamRef}, {continue, ws_await}};

handle_continue(ws_await, #state{ws_pid = Pid, stream_ref = Ref} = State) ->
  case gun:await(Pid, Ref) of
    {upgrade, [<<"websocket">>], _RespHeaders} ->
      {noreply, State};
    {error, Reason} ->
      ?LOG_ERROR("ws_await FAILED. Reason = ~p", [Reason]),
      {stop, Reason, State}
  end.

%% @hidden
-spec terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()), State :: term()) ->
  term().

terminate(_, #state{ws_pid = Pid, stream_ref = Ref}) ->
  ws_close(Pid, Ref),
  ok.

%% @hidden
-spec code_change(OldVsn :: (term() | {down, term()}), State :: term(), Extra :: term()) ->
  {ok, NewState :: term()}
  | {error, Reason :: term()}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%% ==================================================================
%%% Internal functions
%%% ==================================================================

%% @hidden
-spec host_info() -> {binary(), non_neg_integer()}.
host_info() ->
  Host = doteki:get_env(?APP_NAME, ios_host),
  Port = doteki:get_env(?APP_NAME, ios_port),
  {Host, Port}.

%% @hidden
-spec ws_close(pid(), gun:stream_ref()) -> ok.
ws_close(Pid, Ref) ->
  ok = gun:shutdown(Pid),
  ok = gun:flush(Pid),
  ok = gun:flush(Ref).

%% @hidden
-spec ws_send(pid(), gun:stream_ref(), binary()) ->
  {ok, binary()}
  | {error, timeout | {stream_error | connection_error | down, any()}}.
ws_send(Pid, Ref, Req) ->
  ok = gun:ws_send(Pid, Ref, {text, Req}),
  case gun:await(Pid, Ref, 30000) of % TODO: Hardcoded await timeout
    {ws, {Tag, Resp}} when Tag =:= text; Tag =:= binary ->
      {ok, Resp};
    {ws, {close, _Code, _Data}} ->
      {error, closed};
    {error, Reason} ->
      % TODO: {error, {down, noproc}}
      ?LOG_ERROR("ws_send FAILED. Req = ~p, Reason = ~p", [Req, Reason]),
      {error, Reason}
  end.

%% @hidden
-spec prepare_req_seq(maps:map()) -> {ok, maps:map()} | {error, term()}.
prepare_req_seq(#{<<"username">> := Username, <<"password">> := Password} = Data) ->
  WithEncryptedToken = maps:get(<<"with_jwe">>, Data, false),
  [
    ?SWARM_REQ_SESSION(?UUIDv4BinStr, ?SITE_ID, ?SOURCE_ID, ?LANG),
    ?SWARM_REQ_LOGIN(?UUIDv4BinStr, Username, Password, WithEncryptedToken),
    ?SWARM_GET_USER(?UUIDv4BinStr) % or ?SWARM_REQ_PROFILE(?UUIDv4BinStr)
  ];
prepare_req_seq(#{<<"user_id">> := UserId, <<"auth_token">> := AuthToken}) ->
  [
    ?SWARM_REQ_SESSION(?UUIDv4BinStr, ?SITE_ID, ?SOURCE_ID, ?LANG),
    ?SWARM_REQ_RESTORE_LOGIN(?UUIDv4BinStr, UserId, AuthToken), %
    ?SWARM_GET_USER(?UUIDv4BinStr)
  ];
prepare_req_seq(#{<<"jwe_token">> := JweToken, <<"auth_token">> := AuthToken}) ->
  [
    ?SWARM_REQ_SESSION(?UUIDv4BinStr, ?SITE_ID, ?SOURCE_ID, ?LANG),
    ?SWARM_REQ_LOGIN_ENCRYPTED(?UUIDv4BinStr, JweToken, AuthToken),
    ?SWARM_GET_USER(?UUIDv4BinStr)
  ];
prepare_req_seq(#{<<"jwe_token">> := JweToken}) ->
  [
    ?SWARM_REQ_SESSION(?UUIDv4BinStr, ?SITE_ID, ?SOURCE_ID, ?LANG),
    ?SWARM_REQ_LOGIN_ENCRYPTED(?UUIDv4BinStr, JweToken),
    ?SWARM_GET_USER(?UUIDv4BinStr)
  ].

%% TODO: Refactor
%% Sends sequence of requests then return response for last request in the sequence.
-spec send_req_seq({pid(), gun:stream_ref()}, [maps:map(), ...]) ->
  {ok, maps:map()}
  | {error, term()}.
send_req_seq({ConnPid, StreamRef}, [H]) ->
  Json = ?JSON_ENCODE(H),
  case ws_send(ConnPid, StreamRef, Json) of
    {ok, RespJson} ->
      %{ok, _} = ws_send(ConnPid, StreamRef, ?JSON_ENCODE(?SWARM_REQ_LOGOUT)),
      {ok, _} = ws_send(ConnPid, StreamRef, ?JSON_ENCODE(?SWARM_REQ_REMOVE_SESSION)),
      {ok, ?JSON_DECODE(RespJson)};
    {error, Reason} ->
      ws_close(ConnPid, StreamRef),
      {error, Reason}
  end;
send_req_seq({ConnPid, StreamRef}, [H|T]) ->
  Req = ?JSON_ENCODE(H),
  case ws_send(ConnPid, StreamRef, Req) of
    {ok, Resp} ->
      RespDec = ?JSON_DECODE(Resp),
      case RespDec of
        #{<<"code">> := 0} ->
          send_req_seq({ConnPid, StreamRef}, T);
        RespDec ->
          {ok, _} = ws_send(ConnPid, StreamRef, ?JSON_ENCODE(?SWARM_REQ_REMOVE_SESSION)),
          {error, RespDec}
      end;
    {error, Reason} ->
      ws_close(ConnPid, StreamRef),
      {error, Reason}
  end.

-spec swarm_error(integer()) -> {error, atom() | {atom(), integer()}}.
swarm_error(1) -> {error, bad_request};
swarm_error(2) -> {error, invalid_command};
swarm_error(3) -> {error, service_unavailable};
swarm_error(5) -> {error, session_not_found};
swarm_error(6) -> {error, subscription_not_found};
swarm_error(7) -> {error, not_subscribed};
swarm_error(10) -> {error, invalid_level};
swarm_error(11) -> {error, invalid_field};
swarm_error(12) -> {error, invalid_credentials};
swarm_error(13) -> {error, invalid_tree_mode};
swarm_error(14) -> {error, query_syntax_is_invalid};
swarm_error(15) -> {error, invalid_regular_expression};
swarm_error(16) -> {error, invalid_source};
swarm_error(17) -> {error, unsupported_format_exception};
swarm_error(18) -> {error, file_size_exception};
swarm_error(20) -> {error, insufficient_balance};
swarm_error(21) -> {error, operation_not_allowed};
swarm_error(22) -> {error, limit_reached};
swarm_error(23) -> {error, temporary_unavailable};
swarm_error(24) -> {error, abusive_content};
swarm_error(25) -> {error, birth_date_should_be_provided};
swarm_error(26) -> {error, invalid_promo_code};
swarm_error(27) -> {error, recaptcha_verification_needed};
swarm_error(28) -> {error, token_has_expired};
swarm_error(29) -> {error, recaptcha_has_not_verified};
swarm_error(30) -> {error, geo_restricted};
swarm_error(50) -> {error, payment_services_is_unavailable};
swarm_error(99) -> {error, no_response_from_drone};
swarm_error(301) -> {error, moved_permanently};
swarm_error(N) -> {error, {unexpected_error_code, N}}.