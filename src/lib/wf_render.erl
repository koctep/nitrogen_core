% vim: sw=4 ts=4 et ft=erlang
% Nitrogen Web Framework for Erlang
% Copyright (c) 2008-2010 Rusty Klophaus
% See MIT-LICENSE for licensing information.

-module (wf_render).
-include_lib ("wf.hrl").
-export ([
    render/5
]).

render(Elements, Actions, Anchor, Trigger, Target) ->
    % Save any queued actions...
    OldQueuedActions = wf_context:actions(),
    wf_context:clear_actions(),

    % First, render the elements.
    {ok, Html} = wf_render_elements:render_elements(Elements),

    % Second, render any actions.
    {ok, Script1} = wf_render_actions:render_actions(Actions, Anchor, Trigger, Target),

    % Third, render queued actions that were a result of step 1 or 2.
    QueuedActions = wf_context:actions(),
    {ok, Script2} = wf_render_actions:render_actions(QueuedActions, Anchor, Trigger, Target),

    % Restore queued actions...
    wf_context:actions(OldQueuedActions),

    % Return.
    Script=[Script1, Script2],
    {ok, Html1} = set_modules_html(iolist_to_binary(Html)),
    {ok, Html1, Script}.

set_modules_html(Html) ->
    set_module_html(re:split(Html, "\\[\\[(.*)\\]\\]", [ungreedy, {parts, 2}])).

set_module_html([Html, ModuleStr | Rest]) ->
    Elements = case re:split(ModuleStr, "/") of
        [<<"script">>] -> [];
        [<<"mobile_script">>] -> mobile_script;
        [ModuleBin] ->
            Module = wf:to_atom(ModuleBin),
            callback(Module, view, []);
        [ModuleBin, FunBin | ArgV] ->
            Module = wf:to_atom(ModuleBin),
            Fun = wf:to_atom(FunBin),
            callback(Module, Fun, ArgV)
    end,
    {ok, Html1} = wf_render_elements:render_elements(Elements),
    set_modules_html(iolist_to_binary([Html, Html1 | Rest]));
set_module_html(Data) ->
    {ok, binary_to_list(iolist_to_binary(Data))}.

callback(page, Fun, Args) ->
    callback(wf_context:page_module(), Fun, Args);
callback(Module, Fun, Args) ->
    erlang:apply(Module, Fun, Args).
