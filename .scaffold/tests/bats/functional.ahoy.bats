#!/usr/bin/env bats

load _helper
load _assert_functional

export BATS_FIXTURE_EXPORT_CODEBASE_ENABLED=1

# bats file_tags=p1
@test "ahoy build" {
  run ahoy build
  assert_success
  assert_output_contains "PROVISION COMPLETE"
}

@test "ahoy assemble" {
  run ahoy assemble
  assert_success

  assert_output_contains "ASSEMBLE COMPLETE"
  assert_dir_exists "${BUILD_DIR}/build/vendor"
  assert_file_exists "${BUILD_DIR}/build/composer.json"
  assert_file_exists "${BUILD_DIR}/build/composer.lock"
  assert_dir_exists "${BUILD_DIR}/node_modules"
  assert_output_contains "Would run build"
}

@test "ahoy assemble - skip NPM build" {
  touch ".skip_npm_build"

  run ahoy assemble
  assert_success

  assert_output_contains "ASSEMBLE COMPLETE"
  assert_dir_exists "${BUILD_DIR}/build/vendor"
  assert_file_exists "${BUILD_DIR}/build/composer.json"
  assert_file_exists "${BUILD_DIR}/build/composer.lock"
  assert_dir_exists "${BUILD_DIR}/node_modules"
  assert_output_not_contains "Would run build"
}

@test "ahoy start" {
  run ahoy start
  assert_failure
  assert_output_not_contains "ENVIRONMENT READY"

  ahoy assemble
  run ahoy start
  assert_success

  assert_output_contains "ENVIRONMENT READY"
}

@test "ahoy stop" {
  run ahoy stop
  assert_success
  assert_output_contains "ENVIRONMENT STOPPED"

  ahoy assemble
  ahoy start

  run ahoy stop
  assert_success
  assert_output_contains "ENVIRONMENT STOPPED"
}

@test "ahoy provision" {
  run ahoy assemble
  run ahoy start
  run ahoy provision
  assert_success
  assert_output_contains "PROVISION COMPLETE"
  assert_output_not_contains "Do you really want to drop all tables in the database"
  run ahoy provision
  assert_success
  assert_output_contains "PROVISION COMPLETE"
  assert_output_contains "Do you really want to drop all tables in the database"
}

@test "ahoy build - basic workflow" {
  run ahoy build
  assert_success
  assert_output_contains "PROVISION COMPLETE"

  run ahoy drush status
  assert_success
  assert_output_contains "Database         : Connected"
  assert_output_contains "Drupal bootstrap : Successful"

  run ahoy login
  assert_success
  assert_output_contains "user/reset/1/"

  ahoy lint
  assert_success

  ahoy test
  assert_success
  assert_dir_exists "${BUILD_DIR}/build/web/sites/simpletest/browser_output"
}

@test "ahoy lint, lint-fix" {
  ahoy assemble
  assert_success

  ahoy lint
  assert_success

  # shellcheck disable=SC2016
  echo '$a=123;echo $a;' >>your_extension.module
  run ahoy lint
  assert_failure

  run ahoy lint-fix
  run ahoy lint
  assert_success
}

@test "ahoy test unit failure" {
  run ahoy assemble
  assert_success

  run ahoy test-unit
  assert_success

  assert_test_coverage

  sed -i -e "s/assertEquals/assertNotEquals/g" "${BUILD_DIR}/tests/src/Unit/YourExtensionServiceUnitTest.php"
  run ahoy test-unit
  assert_failure
}

@test "ahoy test functional failure" {
  run ahoy build
  assert_success

  run ahoy test-functional
  assert_success
  assert_dir_exists "${BUILD_DIR}/build/web/sites/simpletest/browser_output"

  sed -i -e "s/responseContains/responseNotContains/g" "${BUILD_DIR}/tests/src/Functional/YourExtensionFunctionalTest.php"
  run ahoy test-functional
  assert_failure
}

@test "ahoy test kernel failure" {
  run ahoy build
  assert_success

  run ahoy test-kernel
  assert_success

  sed -i -e "s/assertEquals/assertNotEquals/g" "${BUILD_DIR}/tests/src/Kernel/YourExtensionServiceKernelTest.php"
  run ahoy test-kernel
  assert_failure
}
