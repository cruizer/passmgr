#!/bin/bash
. ../passmgr.sh testsource
# Simple mock function that stores the args it was called with in a variable
mock()
{
	mockcalled="yes"
	mockresult="$@"
}
# Replace $1 with mock() and store $1 in $beforemock temporarily
mock_f()
{
	mockcalled="no"
	beforemock=$(declare -f $1)
	local mock=$(declare -f mock)
	local mocked_f="$1${mock#mock}"
	eval "$mocked_f"
}
# Restore last function mocked with mock_f
demock_f()
{
	if [[ $beforemock ]];then
		eval "$beforemock"
	fi
}
tearDown()
{
	demock_f
}
# BEGIN Test Cases
testCheckParnumSuccesRetcode()
{
  local result
  result=$(check_parnum 3 3)
  assertTrue "check_parnum returned with non-zero code" $?
}
testCheckParnumSuccessOutput()
{
  local result
  result=$(check_parnum 3 3)
  assertNull "check_parnum returned output" "$result"
}
testCheckParnumFailureRetcode()
{
  local result
  result=$(check_parnum 3 4)
  assertFalse "check_parnum returned with zero code" $?
}
testCheckParnumFailureOutput()
{
  local result expected
  mock_f usage
  result=$(check_parnum 3 4)
  expected="Illegal number of parameters."
  assertEquals "check_parnum returned invalid output" \
    "Illegal number of parameters." "$result"
}
testCheckParnumSuccessUsageCall()
{
	local result expected
	expected="no"
	mock_f usage
	result=$(check_parnum 3 3)
	assertEquals "check_parnum called usage on succes" \
		$expected $mockcalled
}
testCheckParnumFailureUsageCall()
{
	local expected
	expected="yes"
	mock_f usage
	check_parnum 3 4 > /dev/null
	assertEquals "check_parnum did not call usage on failure" \
		$expected $mockcalled
}
# END Test Cases
# load shUnit2
. ./lib/shunit2/source/2.1/src/shunit2
