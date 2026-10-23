#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h:h}"
timestamp="$(date +%Y%m%d-%H%M%S)"
derived_data="${CMV_STOREKIT_DERIVED_DATA:-/tmp/cmv-hosted-storekit-local-${timestamp}}"
manifest="${derived_data}/storekit-local-manifest.tsv"
project="${repo_root}/Native/CMV/CMV.xcodeproj"
destination="${CMV_STOREKIT_DESTINATION:-platform=macOS,arch=arm64}"
bundle_id="${CMV_STOREKIT_BUNDLE_ID:-com.windsheep.cmv.storekitqa}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  print -u2 "xcodebuild not found"
  exit 127
fi
if ! command -v python3 >/dev/null 2>&1; then
  print -u2 "python3 not found (required to validate xcresult test counts)"
  exit 127
fi

mkdir -p "${derived_data}"
print -r -- $'case\tstatus\tresultBundle\tproof' > "${manifest}"

# Device tests can use an existing cached Development profile. Without a team,
# keep the local Mac/Simulator ad-hoc signing path.
typeset -a signing_args
if [[ -n "${CMV_STOREKIT_DEVELOPMENT_TEAM:-}" ]]; then
  signing_args=(
    "DEVELOPMENT_TEAM=${CMV_STOREKIT_DEVELOPMENT_TEAM}"
    "CODE_SIGN_STYLE=Automatic"
    "CODE_SIGN_IDENTITY=Apple Development"
  )
else
  signing_args=("CODE_SIGN_IDENTITY=-" "CODE_SIGNING_REQUIRED=NO")
fi

typeset -a cases
cases=(
  "testPendingApprovalArrivesThroughUpdates"
  "testPendingDeclineDoesNotGrantAccess"
  "testRawStoreKitPendingApprovalDelivery"
  "testPendingApprovalAfterSingleStartupRefresh"
  "testPendingApprovalRawListenerWithProductionPurchase"
  "testPendingApprovalProductionListenerWithDirectPurchase"
  "testPendingApprovalRefreshReconcilesVerifiedEntitlement"
  "testExternalPurchaseArrivesThroughUpdates"
  "testPurchaseRestartRestoreAndRefund"
  "testCancellationAndFailureDoNotGrantAccess"
  "testVerifiedAccessSurvivesProductNetworkFailureOnRestart"
  "testRestoreNetworkFailurePreservesVerifiedAccess"
  "testUnverifiedPurchaseDoesNotGrantAccess"
  "testUnverifiedRefreshPreservesPreviousVerifiedAccess"
  "testMissingProductCannotPurchaseOrGrantAccess"
  "testRefundRevokesAccessThroughUpdates"
  "testConcurrentPurchaseAndRestoreDoNotDuplicateTransactions"
)

overall=0
for test_case in "${cases[@]}"; do
  result_bundle="${derived_data}/${test_case}-${timestamp}.xcresult"
  log_file="${derived_data}/${test_case}.log"
  summary_file="${derived_data}/${test_case}-summary.json"
  result_status="FAIL"
  build_succeeded=0
  if xcodebuild \
      -project "${project}" \
      -scheme CMV-StoreKit-Local \
      -configuration Debug \
      -destination "${destination}" \
      -derivedDataPath "${derived_data}" \
      -resultBundlePath "${result_bundle}" \
      -jobs 1 \
      CMV_APP_BUNDLE_IDENTIFIER="${bundle_id}" \
      SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG CMV_STOREKIT_TEST_HOST' \
      "${signing_args[@]}" \
      -parallel-testing-enabled NO \
      "-only-testing:CMVProTests/ProStoreTransactionTests/${test_case}" \
      test >"${log_file}" 2>&1; then
    build_succeeded=1
  fi

  proof="missing xcresult test summary"
  if xcrun xcresulttool get test-results summary --path "${result_bundle}" --compact >"${summary_file}" 2>>"${log_file}"; then
    # xcodebuild can exit successfully when -only-testing selects no tests.
    # Require one executed, passed test; skipped or absent tests are failures.
    if proof="$(python3 - "${summary_file}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    summary = json.load(source)
counts = [summary.get(key) for key in
          ("totalTestCount", "passedTests", "failedTests", "skippedTests")]
print("total={}, passed={}, failed={}, skipped={}".format(*counts))
sys.exit(0 if counts == [1, 1, 0, 0] and summary.get("result") == "Passed" else 1)
PY
    )"; then
      if (( build_succeeded )); then
        result_status="PASS"
      fi
    fi
  fi
  [[ "${result_status}" == "PASS" ]] || overall=1
  print -r -- "${test_case}"$'\t'"${result_status}"$'\t'"${result_bundle}"$'\t'"${proof}" | tee -a "${manifest}"
done

print -r -- "manifest=${manifest}"
exit "${overall}"
