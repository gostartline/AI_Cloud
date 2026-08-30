#!/usr/bin/env bash
set -Eeuo pipefail

validate_llm_response() {
  local response_file="$1" expected_content="$2" summary_file="$3"

  if ! jq '{
    model: (.model // null),
    finish_reason: (.choices[0].finish_reason // null),
    assistant_content: (.choices[0].message.content // null),
    prompt_tokens: (.usage.prompt_tokens // null),
    completion_tokens: (.usage.completion_tokens // null),
    total_tokens: (.usage.total_tokens // null),
    predicted_per_second: (.timings.predicted_per_second // null)
  }' "${response_file}" > "${summary_file}"; then
    return 1
  fi

  if ! jq -e --arg expected_content "${expected_content}" '
    (.model | strings | length > 0) and
    .finish_reason == "stop" and
    .assistant_content == $expected_content and
    (.prompt_tokens | numbers) and
    (.completion_tokens | numbers) and
    (.total_tokens | numbers) and
    (.predicted_per_second | numbers)
  ' "${summary_file}" >/dev/null; then
    return 1
  fi
}
