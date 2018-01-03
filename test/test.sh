#!/bin/bash
. ../passmgr.sh testsource
PASSMGRDATAFILE="test_pwfile.test"
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
testUsageRetCode()
{
	local result expected
	expected=5
	result=$(usage 5)
	assertEquals "usage returned with incorrect code" $expected $?
}
testUsageOutput()
{
	local result expected
	expected="Usage: passmgr addpass OR passmgr readpass|rmpass <name>"
	result=$(usage 2)
	assertEquals "usage returned with incorrect output" \
		"$expected" "$result"
}
testCheckPwFileSuccessRetCode()
{
	local result
	touch "$PASSMGRDATAFILE"
	result=$(check_pwfile hard)
	rm "$PASSMGRDATAFILE"
	assertTrue "check_pwfile hard returned non zero code" $?
}
testCheckPwFileHardFailureRetCode()
{
	local result expected
	expected=3
	result=$(check_pwfile hard)
	assertEquals "check_pwfile hard returned code other than 3" \
		$expected $?
}
testCheckPwFileSoftFailureRetCode()
{
	local result expected
	expected=1
	result=$(check_pwfile soft)
	assertEquals "check_pwfile soft returned code other than 1" \
		$expected $?
}
testCheckPwFileUnknownFailureRetCode()
{
	local result expected
	expected=7
	result=$(check_pwfile other)
	assertEquals "check_pwfile unknown returned code other than 7" \
		$expected $?
}
testCheckPwFileSuccessOutput()
{
	local result expected
	touch "$PASSMGRDATAFILE"
	expected="Password data file found."
	result=$(check_pwfile hard)
	rm "$PASSMGRDATAFILE"
	assertEquals "check_pwfile hard returned incorrect output" \
		"$expected" "$result"
}
# END Test Cases
# load shUnit2
. ./lib/shunit2/source/2.1/src/shunit2
