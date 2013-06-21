% vim: sw=4 ts=4 et ft=erlang
% Nitrogen Web Framework for Erlang
% Copyright (c) 2008-2010 Rusty Klophaus
% See MIT-LICENSE for licensing information.

-module (element_template).
-include_lib ("wf.hrl").
-compile(export_all).

% TODO - Revisit parsing in the to_module_callback. This
% will currently fail if we encounter a string like:
% "String with ) will fail"
% or
% "String with ]]] will fail"


reflect() -> record_info(fields, template).

render_element(Record) ->
    % Parse the template file...

    File = wf:to_list(Record#template.file),
    Template = get_cached_template(File),

    Template.

get_cached_template(File) ->
    FileAtom = list_to_atom("template_file_" ++ File),

    LastModAtom = list_to_atom("template_lastmod_" ++ File),
    LastMod = nitro_mochiglobal:get(LastModAtom),

    CacheTimeAtom = list_to_atom("template_cachetime_" ++ File),
    CacheTime = nitro_mochiglobal:get(CacheTimeAtom),

    %% Check for recache if one second has passed since last cache time...
    ReCache = case (CacheTime == undefined) orelse (timer:now_diff(now(), CacheTime) > (1000 * 1000)) of
        true ->
            %% Recache if the file has been modified. Otherwise, reset
            %% the CacheTime timer...
            case LastMod /= filelib:last_modified(File) of
                true ->
                    true;
                false ->
                    nitro_mochiglobal:put(CacheTimeAtom, now()),
                    false
            end;
        false ->
            false
    end,

    case ReCache of
        true ->
            %% Recache the template...
            Template = parse_template(File),
            nitro_mochiglobal:put(FileAtom, Template),
            nitro_mochiglobal:put(LastModAtom, filelib:last_modified(File)),
            nitro_mochiglobal:put(CacheTimeAtom, now()),
            Template;
        false ->
            %% Load template from cache...
            nitro_mochiglobal:get(FileAtom)
    end.

parse_template(File) ->
    % TODO - Templateroot
    % File1 = filename:join(nitrogen:get_templateroot(), File),
    File1 = File,
    case file:read_file(File1) of
        {ok, B} -> [B];
        _ ->
            ?LOG("Error reading file: ~s~n", [File1]),
            throw({template_not_found, File1})
    end.
