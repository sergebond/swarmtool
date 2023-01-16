-ifndef(ALLINN_AUTH_SWARM_HRL).
-define(ALLINN_AUTH_SWARM_HRL, true).

-define(SITE_ID, 18747305).
-define(SOURCE_ID, 103).
-define(LANG, <<"eng">>).

-define(CONN_TIMEOUT_SEC, 120).
-define(AWAIT_TIMEOUT_SEC, 120).
-define(CLOSING_TIMEOUT_SEC, 60).

-define(SWARM_REQ_SESSION(ReqId, SiteId, SourceId, Lang),
  #{
    <<"command">> => <<"request_session">>,
    <<"params">> => #{
      <<"site_id">> => SiteId,
      <<"source">> => SourceId,
      <<"language">> => Lang
    },
    <<"rid">> => ReqId
  }).

-define(SWARM_REQ_REMOVE_SESSION,
  #{
    <<"command">> => <<"remove_session">>
  }).

-define(SWARM_REQ_LOGIN(ReqId, Username, Password),
  #{
    <<"command">> => <<"login">>,
    <<"params">> => #{
      <<"username">> => Username,
      <<"password">> => Password
    },
    <<"rid">> => ReqId
  }).

-define(SWARM_REQ_LOGIN(ReqId, Username, Password, WithEncryptedToken),
  #{
    <<"command">> => <<"login">>,
    <<"params">> => #{
      <<"username">> => Username,
      <<"password">> => Password,
      <<"encrypted_token">> => WithEncryptedToken
    },
    <<"rid">> => ReqId
  }).

-define(SWARM_REQ_RESTORE_LOGIN(ReqId, UserId, AuthToken),
  #{
    <<"command">> => <<"restore_login">>,
    <<"params">> => #{
      <<"user_id">> => UserId,
      <<"auth_token">> => AuthToken
    },
    <<"rid">> => ReqId
  }).

-define(SWARM_REQ_LOGIN_ENCRYPTED(ReqId, JweToken),
  #{
    <<"command">> => <<"login_encrypted">>,
    <<"params">> => #{
      <<"jwe_token">> => JweToken
    },
    <<"rid">> => ReqId
  }).

-define(SWARM_REQ_LOGIN_ENCRYPTED(ReqId, JweToken, AuthToken),
  #{
    <<"command">> => <<"login_encrypted">>,
    <<"params">> => #{
      <<"jwe_token">> => JweToken,
      <<"auth_token">> => AuthToken
    },
    <<"rid">> => ReqId
  }).

-define(SWARM_REQ_LOGOUT,
  #{
    <<"command">> => <<"logout">>,
    <<"params">> => #{}
  }).

-define(SWARM_REQ_SECURE_LOGOUT(ReqId, JweToken),
  #{
    <<"command">> => <<"secure_logout">>,
    <<"params">> => #{
      <<"jwe_token">> => JweToken
    },
    <<"rid">> => ReqId
  }).

-define(SWARM_GET_USER(ReqId),
  #{
    <<"command">> => <<"get_user">>,
    <<"params">> => #{},
    <<"rid">> => ReqId
  }).

-define(SWARM_REQ_PROFILE(ReqId),
  #{
    <<"command">> => <<"get">>,
    <<"params">> => #{
      <<"source">> => <<"user">>,
      <<"what">> => #{
        <<"profile">> => []
      },
      <<"subscribe">> => true
    },
    <<"rid">> => ReqId
  }).

-endif.
