#!/bin/bash
. ../passmgr.sh testsource
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
  result=$(check_parnum 3 4 | head -n1)
  expected="Illegal number of parameters."
  assertEquals "check_parnum returned invalid output" \
    "Illegal number of parameters." "$result"
}
# load shUnit2
. ./lib/shunit2/source/2.1/src/shunit2
