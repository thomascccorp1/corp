{{- /*
Return a map which contains the subsystem data map as required by other API calls:

   data:
     ctx: .ctx
     name: $subsystemName
     enabled: true|false

*/ -}}
{{- define "arkcase.subsystem" -}}
  {{- $ctx := . -}}
  {{- $subsysName := "" -}}
  {{- $value := "" -}}
  {{- if hasKey $ctx "Values" -}}
    {{- /* we're fine, we're auto-detecting */ -}}
  {{- else if and (hasKey $ctx "subsystem") (hasKey $ctx "ctx") -}}
    {{- $subsysName = (toString $ctx.subsystem) -}}
    {{- /* Does it also have a value specification? */ -}}
    {{- if (hasKey $ctx "value") -}}
      {{- $value = (toString $ctx.value | required "The 'value' parameter may not be the empty string") -}}
    {{- end -}}
    {{- $ctx = $ctx.ctx -}}
  {{- else -}}
    {{- fail "The provided dictionary must either have 'Values', or both 'subsys' and 'ctx' parameters" -}}
  {{- end -}}

  {{- /* If we've not been given a subsystem name, we detect it */ -}}
  {{- if (empty $subsysName) -}}
    {{- if (hasKey $ctx.Values "arkcase-subsystem") -}}
      {{- $subsysName = get $ctx "arkcase-subsystem" -}}
    {{- else -}}
      {{- $subsysName = .Chart.Name -}}
      {{- $marker := set $ctx "arkcase-subsystem" $subsysName -}}
    {{- end -}}
  {{- end -}}

  {{- /* Start structuring our return value */ -}}
  {{- $map := (dict "ctx" $ctx "name" $subsysName) -}}

  {{- /* Cache the information */ -}}
  {{- $subsys := dict -}}
  {{- if (hasKey $ctx "ArkCaseSubsystem") -}}
    {{- $subsys = get $ctx "ArkCaseSubsystem" -}}
  {{- else -}}
    {{- $crap := set $ctx "ArkCaseSubsystem" $subsys -}}
  {{- end -}}

  {{- $data := dict -}}
  {{- if (hasKey $subsys $subsysName) -}}
    {{- /* Retrieve the cached data */ -}}
    {{- $data = get $subsys $subsysName -}}
  {{- else -}}
    {{- $enabled := (include "arkcase.tools.get" (dict "ctx" $ctx "name" (printf ".Values.global.subsystem.%s" $subsysName))) -}}
    {{- /* Set the "enabled" flag, which defaults to TRUE if it's not set */ -}}
    {{- $enabled = or (empty $enabled) (eq "true" (toString $enabled | lower)) -}}
    {{- if not (kindIs "bool" $enabled) -}}
      {{- $enabled = (eq "true" (toString $enabled | lower)) -}}
    {{- end -}}
    {{- $crap := set $data "enabled" $enabled -}}

    {{- /* Cache the computed data */ -}}
    {{- $crap = set $subsys $subsysName $data -}}
  {{- end -}}
  {{- $crap := set $map "data" $data -}}

  {{- $map | toYaml | nindent 0 -}}
{{- end -}}

{{- /*
Identify the subsystem being used

Parameter: "optional" (not used)
*/ -}}
{{- define "arkcase.subsystem.name" -}}
  {{- get (include "arkcase.subsystem" . | fromYaml) "name" -}}
{{- end -}}

{{- /*
Check whether a subsystem is enabled for provisioning. If it's not enabled, attempting to access its configurations
should result in an error.

Parameter: either the root context (i.e. "." or "$"), or
           a dict with two keys:
             - ctx = the root context (either "." or "$")
             - subsystem = a string with the name of the subsystem to query
*/ -}}
{{- define "arkcase.subsystem.enabled" -}}
  {{- $map := (include "arkcase.subsystem" . | fromYaml) -}}
  {{- if ($map.data.enabled) -}}
    true
  {{- end -}}
{{- end -}}

{{- /*
Render subsystem service declarations based on whether an external host declaration is provided or not
*/ -}}
{{- define "arkcase.subsystem.service" -}}
  {{- $service := (include "arkcase.tools.get" (dict "ctx" . "name" ".Values.service") | fromYaml | default dict) -}}
  {{- $serviceName := (include "arkcase.subsystem.name" .) -}}
  {{- /* Check to see if there are any ports defined ... there must be at least one */ -}}
  {{- if not (empty $service.ports) }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $serviceName | quote }}
  namespace: {{ .Release.Namespace | quote }}
  labels:
	{{- include "common.labels" . | nindent 4 }}
spec:
  {{- if ($service.host) -}}
    {{- if not (include "arkcase.tools.isIp" $service.host) }}
  type: "ExternalName"
  externalName: {{ $service.host | quote }}
    {{- else }}
  ports:
    {{- range $service.ports }}
    - name: {{ .name | required  "No port name given" | quote }}
      protocol: {{ .protocol | required "No port protocol given" | quote }}
      port: {{ (int .port) | required "Port number must not be 0" }}
      targetPort: {{ (int .targetPort) | default (int .port) }}
    {{- end }}
---
apiVersion: v1
kind: Endpoints
metadata:
  name: {{ $serviceName | quote }}
  namespace: {{ .Release.Namespace | quote }}
  labels:
	{{- include "common.labels" . | nindent 4 }}
subsets:
  - addresses:
      - ip: {{ $service.host | quote }}
    ports:
    {{- range $service.ports }}
      - name: {{ .name | required  "No port name given" | quote }}
        port: {{ (int .port) | required "Port number must not be 0" }}
    {{- end }}
    {{- end -}}
  {{- else }}
  type: {{ $service.type | default "NodePort" | quote }}
  selector:
    # Is this correct?
    {{- include "common.labels" . | nindent 4 }}
  ports:
    {{- range $service.ports }}
    - name: {{ .name | required  "No port name given" | quote }}
      protocol: {{ .protocol | required "No port protocol given" | quote }}
      port: {{ (int .port) | required "Port number must not be 0" }}
      targetPort: {{ (int .targetPort) | default (int .port) }}
    {{- end }}
  {{- end -}}
  {{- end -}}
{{- end -}}
