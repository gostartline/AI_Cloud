# Windows Client Integration

Windows 11 captures are treated as supplementary evidence for the client-facing path:

```text
Windows Client
    -> local forwarded endpoint
    -> Kubernetes service
    -> llama.cpp
    -> Gemma
    -> API response
```

The reviewed captures show the llama.cpp web UI and API-oriented interaction, including Japanese output and client-visible timing/token information. The public package uses the sanitized API summary as the primary artifact and does not rely on browser screenshots for the CPU validation status.

Raw captures are withheld from this package because they contain browser chrome, local URLs/session identifiers, a profile avatar, terminal commands, host/user text, or model-path details. See the file-level audit for the exact classification of `winodws/scr001.png` through `scr006.png` and `winodws/winodws.zip`.
