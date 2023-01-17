%%%-------------------------------------------------------------------
%% @doc swarmtool top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(swarmtool_sup).

-behaviour(supervisor).
-include("swarmtool.hrl").
-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).


init([]) ->
  Pools = [{?POOL_NAME, [
    {size, doteki:get_env(?APP_NAME, pool_size, 3)},
    {max_overflow, doteki:get_env(?APP_NAME, pool_max_overflow, 3)}
  ], []}],

  PoolSpec = lists:map(fun({PoolName, SizeArgs, WorkerArgs}) ->
    PoolArgs = [{name, {local, PoolName}},
      {worker_module, swarmtool_auth_srv}] ++ SizeArgs,

    poolboy:child_spec(PoolName, PoolArgs, WorkerArgs)
                       end, Pools),

  {ok, {{one_for_one, 10, 10}, PoolSpec}}.
%% internal functions
