{{- /*
Return a map which contains the "subsys", "param" and "ctx" keys as required by other API calls
*/ -}}
{{- define "ark-subsys.subsystem" -}}
  {{- $ctx := . -}}
  {{- $subsys := "" -}}
  {{- if hasKey $ctx "Values" -}}
    {{- /* we're fine, we're auto-detecting */ -}}
  {{- else if and (hasKey $ctx "subsys") (hasKey $ctx "ctx") -}}
    {{- $subsys = (toString $ctx.subsys) -}}
    {{- $ctx = $ctx.ctx -}}
  {{- else -}}
    {{- fail "The provided dictionary must either have 'Values', or both 'subsys' and 'ctx' parameters" -}}
  {{- end -}}

  {{- /* If we've not been given a subsystem name, we detect it */ -}}
  {{- if (empty $subsys) -}}
    {{- if (hasKey $ctx.Values "arkcase-subsystem") -}}
      {{- $subsys = get $ctx "arkcase-subsystem" -}}
    {{- else -}}
      {{- /* Check to see that the subsystem data is there */ -}}
      {{- if not (hasKey $ctx.Values.global "subsystem") -}}
        {{- fail "Subsystem data is not defined. Cannot continue." -}}
      {{- end -}}

      {{- /* Check to see that the subsystem mappings are there */ -}}
      {{- if not (hasKey $ctx.Values.global.subsystem "mappings") -}}
        {{- fail "Subsystem mappings are not defined. Cannot continue." -}}
      {{- end -}}

      {{- /* Check to see that there's a mapping for this chart */ -}}
      {{- if not (hasKey $ctx.Values.global.subsystem.mappings .Chart.Name) -}}
        {{- fail (printf "Subsystem mappings don't have an entry for the chart [%s]. Cannot continue." .Chart.Name ) -}}
      {{- end -}}

      {{- $subsys = (get $ctx.Values.global.subsystem.mappings .Chart.Name) -}}
      {{- $marker := set $ctx "arkcase-subsystem" $subsys -}}
    {{- end -}}
  {{- end -}}
  {{- $map := (dict "ctx" $ctx "subsys" $subsys) -}}

  {{- $data := dict -}}
  {{- /* Make a copy of the common subsystem data into the "data" dict */ -}}
  {{- if (hasKey $ctx.Values.global.subsystem "common") -}}
    {{- $data = ($ctx.Values.global.subsystem.common | mustDeepCopy) -}}
  {{- end -}}
  {{- if (hasKey $ctx.Values.global.subsystem $subsys) -}}
    {{- $data = (get $ctx.Values.global.subsystem $subsys | mustDeepCopy | mustMergeOverwrite $data) -}}
  {{- end -}}
  {{- $map = (set $map "data" $data) -}}

  {{- /* Does it also have a parameter specification? */ -}}
  {{- if hasKey $ctx "param" -}}
    {{- $param := (set $map "param" (toString (get $ctx "param"))) -}}
  {{- end -}}

  {{- $map | toYaml | nindent 0 -}}
{{- end -}}

{{- /*
Identify the subsystem being used

Parameter: "optional" (not used)
*/ -}}
{{- define "ark-subsys.subsystem.name" -}}
  {{- get (include "ark-subsys.subsystem" . | fromYaml) "subsys" -}}
{{- end -}}

{{- /*
Identify whether the subsystem's external endpoint is to be used or not

Parameter: either the root context (i.e. "." or "$"), or
           a dict with two keys:
             - subsys = a string with the name of the subsystem to query
             - ctx = the root context (either "." or "$")
*/ -}}
{{- define "ark-subsys.subsystem.external" -}}
  {{- $map := (include "ark-subsys.subsystem" . | fromYaml) -}}
  {{- $ctx := $map.ctx -}}
  {{- $subsys := $map.subsys -}}
  {{- $enabled := (eq 1 0) -}}
  {{- if (hasKey $ctx.Values.global.subsystem $subsys) -}}
    {{- $map := get $ctx.Values.global.subsystem $subsys -}}
    {{- if (hasKey $map "external") -}}
      {{- $external := get $map "external" -}}
      {{- if (hasKey $external "enabled") -}}
        {{- $enabled = get $external "enabled" -}}
        {{- if not (kindIs "bool" $enabled) -}}
          {{- if (eq "true" (toString $enabled | lower)) -}}
            {{- $enabled = true -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if $enabled -}}
    true
  {{- end -}}
{{- end -}}

{{- /*
Retrieve a parameter for the external subsystem.

Parameter: a dict with either two or three keys:
             - subsys = (optional) a string with the name of the subsystem to query
             - value = a string with the name/path of the value to query (will be evaled with tpl)
             - ctx = the root context (either "." or "$")
*/ -}}
{{- define "ark-subsys.subsystem.external.get" -}}
  {{- $map := (include "ark-subsys.subsystem" . | fromYaml) -}}
  {{- $ctx := $map.ctx -}}
  {{- $subsys := $map.subsys -}}
  {{- if not (hasKey $map "param") -}}
    {{- fail "Must provide the name of the parameter to fetch in the parameter dict" -}}
  {{- else if empty $map.param -}}
    {{- fail "The name of the parameter to fetch may not be empty in the parameter dict" -}}
  {{- end -}}
  {{- $value := (tpl $map.param $map.data) -}}
  {{- /* TODO: If the value is a scalar, then just spit it out, otherwise toYaml it for consumption on the other end */ -}}
  {{- $value -}}
{{- end -}}
