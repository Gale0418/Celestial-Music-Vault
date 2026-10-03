#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h:h}"
timestamp="$(date +%Y%m%d-%H%M%S)"
derived_data="${CMV_STOREKIT_DERIVED_DATA:-/tmp/cmv-hosted-storekit-local-${timestamp}}"
manifest="${derived_data}/storekit-local-manifest.tsv"
project="${repo_root}/Native/CMV/CMV.xcodeproj"

if ! command -v xcodebuild >/dev/null 2>&1; then
  print -u2 "xcodebuild not found"
  exit 127
fi
if ! command -v rg >/dev/null 2>&1; then
  print -u2 "rg not found"
  exit 127
fi

mkdir -p "${derived_data}"
print -r -- $'case\tstatus\tresultBundle\tproof' > "${manifest}"

typeset -a cases
cases=(
  "testPendingApprovalAndDecline"
  "testPurchaseRestartRestoreAndRefund"
  "testCancellationAndFailureDoNotGrantAccess"
)

overall=0
for test_case in "${cases[@]}"; do
  result_bundle="${derived_data}/${test_case}-${timestamp}.xcresult"
  log_file="$(mktemp -t cmv-storekit-local)"
  result_status="FAIL"
  if xcodebuild \
      -project "${project}" \
      -scheme CMV-StoreKit-Local \
      -configuration Debug \
      -destination 'platform=macOS,arch=arm64' \
      -derivedDataPath "${derived_data}" \
      -resultBundlePath "${result_bundle}" \
      -jobs 1 \
      CMV_APP_BUNDLE_IDENTIFIER=com.windsheep.cmv.storekitqa \
      SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG CMV_STOREKIT_TEST_HOST' \
      CODE_SIGN_IDENTITY=- \
      CODE_SIGNING_REQUIRED=NO \
      -parallel-testing-enabled NO \
      "-only-testing:CMVProTests/ProStoreTransactionTests/${test_case}" \
      test >"${log_file}" 2>&1; then
    result_status="PASS"
  else
    overall=1
  fi

  proof="$(rg -o 'Executed [0-9]+ tests?, with [0-9]+ failures? \([^)]*\)' "${log_file}" | tail -1 | tr '\n' ' ' || true)"
  if [[ -z "${proof}" ]]; then
    proof="no sanitized test summary"
  fi
  print -r -- "${test_case}"$'\t'"${result_status}"$'\t'"${result_bundle}"$'\t'"${proof}" | tee -a "${manifest}"
  rm -f "${log_file}"
done

print -r -- "manifest=${manifest}"
exit "${overall}"
