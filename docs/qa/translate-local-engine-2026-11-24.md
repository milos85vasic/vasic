# Translate-pipeline local engine - 2026-11-24 (RED then GREEN)

RED (before): i18n_probe rc 2, 'all providers exhausted' (shim ssh to unresolvable fleet; groq llama-3.3-70b-versatile 404; mistral-large-latest 403 tier_not_allowed; deepseek 402 Insufficient Balance; cerebras llama-3.3-70b 404; gemini 400; openrouter :free 404).
GREEN (after): probe prints REACHABLE, pipeline output {"nav.inbox":"Prijem"} via groq:openai/gpt-oss-120b; direct engine: sr 'Vas inbox je prazan...', ru 'Ваша папка входящих пуста...'.
Image: localhost/helixtranslate:cli built from Containerfile.translator with context $VASIC_FAST_STORE/helix_translate (local, untracked).
