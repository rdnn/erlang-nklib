%% -------------------------------------------------------------------
%%
%% Copyright (c) 2019 Carlos Gonzalez Florido.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc Common library utility functions
-module(nklib_parse_trans_vsn).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').

-export([parse_transform/2]).


%% ===================================================================
%% Public
%% ===================================================================

%% @doc Replaces do_fun/1 for a version compatible with erlang pre and post 21
parse_transform(Forms, _Opts) ->
    Forms2 = forms_replace_fun(do_try, 1, make_try_fun(), Forms),
    Forms3 = forms_replace_fun(do_config_get, 1, make_get_fun1(), Forms2),
    Forms4 = forms_replace_fun(do_config_get, 2, make_get_fun2(), Forms3),
    Forms5 = forms_replace_fun(do_config_put, 2, make_put_fun2(), Forms4),
    Forms6 = forms_replace_fun(do_config_del, 1, make_del_fun1(), Forms5),
    Forms6.


%% @private
make_try_fun() ->
    Exp = case is_21() of
        true ->
            "
                do_try(Fun) ->
                    try Fun()
                catch
                    throw:Throw -> {exception, {throw, {Throw, []}}};
                    Class:Error:Trace -> {exception, {Class, {Error, Trace}}}
                end.
            ";
        false ->
            "
                do_try(Fun) ->
                    try Fun()
                catch
                    throw:Throw -> {exception, {throw, {Throw, []}}};
                    Class:Error -> {exception, {Class, {Error, []}}}
                end.
            "
    end,
    forms_expression(Exp).


%% @private
make_get_fun1() ->
    Exp = case is_21_2() of
        true ->
            "
                do_config_get(Key) ->
                    persistent_term:get(Key).
            ";
        false ->
            "
                do_config_get(Key) ->
                    nklib_config:get(nklib_trans_comp, Key).
            "
    end,
    forms_expression(Exp).


%% @private
make_get_fun2() ->
    Exp = case is_21_2() of
        true ->
            "
                do_config_get(Key, Default) ->
                    persistent_term:get(Key, Default).
            ";
        false ->
            "
                do_config_get(Key, Default) ->
                    nklib_config:get(nklib_trans_comp, Key, Default).
            "
    end,
    forms_expression(Exp).


%% @private
make_put_fun2() ->
    Exp = case is_21_2() of
        true ->
            "
                do_config_put(Key, Value) ->
                    persistent_term:put(Key, Value).
            ";
        false ->
            "
                do_config_put(Key, Value) ->
                    nklib_config:put(nklib_trans_comp, Key, Value).
            "
    end,
    forms_expression(Exp).


%% @private
make_del_fun1() ->
    Exp = case is_21_2() of
        true ->
            "
                do_config_del(Key) ->
                    persistent_term:erase(Key).
            ";
        false ->
            "
                do_config_del(Key) ->
                    nklib_config:del(nklib_trans_comp, Key).
            "
    end,
    forms_expression(Exp).


%% @private
is_21() ->
    erlang:system_info(otp_release) >= "21".


%% @private
is_21_2() ->
    % Erlang 21.0: 10.0.8
    % Erlang 21.1: 10.1.8
    % Erlang 21.2: 10.2.1
    is_21() andalso erlang:system_info(version) >= "10.2.1".


%% @private
forms_replace_fun(Name, Arity, Spec, Forms) ->
    forms_replace_fun(Forms, Name, Arity, Spec, []).


%% @private
forms_replace_fun([], _Name, _Arity, _Spec, Acc) ->
    lists:reverse(Acc);

forms_replace_fun([{function, _Line, Name, Arity, _}|Rest], Name, Arity, Spec, Acc) ->
    forms_replace_fun(Rest, Name, Arity, Spec, [Spec|Acc]);

forms_replace_fun([Other|Rest], Name, Arity, Spec, Acc) ->
    forms_replace_fun(Rest, Name, Arity, Spec,  [Other|Acc]).


%% @private
forms_expression(Expr) ->
    {ok, Tokens, _} = erl_scan:string(Expr),
    {ok, Forms} = erl_parse:parse_form(Tokens),
    Forms.
