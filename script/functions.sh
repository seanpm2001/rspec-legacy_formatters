# This file was generated on 2014-03-30T13:16:22-07:00 from the rspec-dev repo.
# DO NOT modify it by hand as your changes will get lost the next time it is generated.

# idea taken from: http://blog.headius.com/2010/03/jruby-startup-time-tips.html
export JRUBY_OPTS='-X-C' # disable JIT since these processes are so short lived
SPECS_HAVE_RUN_FILE=specs.out
MAINTENANCE_BRANCH=`cat maintenance-branch`

# Taken from:
# https://github.com/travis-ci/travis-build/blob/e9314616e182a23e6a280199cd9070bfc7cae548/lib/travis/build/script/templates/header.sh#L34-L53
travis_retry() {
  local result=0
  local count=1
  while [ $count -le 3 ]; do
    [ $result -ne 0 ] && {
      echo -e "\n\033[33;1mThe command \"$@\" failed. Retrying, $count of 3.\033[0m\n" >&2
    }
    "$@"
    result=$?
    [ $result -eq 0 ] && break
    count=$(($count + 1))
    sleep 1
  done

  [ $count -eq 3 ] && {
    echo "\n\033[33;1mThe command \"$@\" failed 3 times.\033[0m\n" >&2
  }

  return $result
}

function is_mri {
  if ruby -e "exit(!defined?(RUBY_ENGINE) || RUBY_ENGINE == 'ruby')"; then
    # RUBY_ENGINE only returns 'ruby' on MRI.
    # MRI 1.8.7 lacks the constant but all other rubies have it (including JRuby in 1.8 mode)
    return 0
  else
    return 1
  fi;
}

function is_mri_192 {
  if is_mri; then
    if ruby -e "exit(RUBY_VERSION == '1.9.2')"; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

function rspec_support_compatible {
  if [ "$MAINTENANCE_BRANCH" != "2-99-maintenance" ] && [ "$MAINTENANCE_BRANCH" != "2-14-maintenance" ]; then
    return 0
  else
    return 1
  fi
}

function rspec_version_defined {
  if [ "$RSPEC_VERSION" != "" ]; then
    return 0
  else
    return 1
  fi
}

function documentation_enforced {
  if [ -x ./bin/yard ]; then
    return 0
  else
    return 1
  fi
}

function run_specs_and_record_done {
  local rspec_bin=bin/rspec

  # rspec-core needs to run with a special script that loads simplecov first,
  # so that it can instrument rspec-core's code before rspec-core has been loaded.
  if [ -f script/rspec_with_simplecov ]; then
    rspec_bin=script/rspec_with_simplecov
  fi;

  $rspec_bin spec --backtrace --format progress --profile --format progress --out $SPECS_HAVE_RUN_FILE
}

function run_sample_specs {
  if [ ! -f ./smoke_specs/$SPECS_HAVE_RUN_FILE ]; then # don't rerun specs that have already run
    pushd ./smoke_specs
    echo
    echo "Running smoke specs for $RSPEC_VERSION"
    echo
    unset BUNDLE_GEMFILE
    bundle_install_flags=`cat ../.travis.yml | grep bundler_args | tr -d '"' | grep -o " .*"`
    travis_retry bundle install $bundle_install_flags
    cp ../.rspec .rspec
    set +e
    bin/rspec spec ../spec --format NyanCatFormatter --format NyanCatFormatter --out $SPECS_HAVE_RUN_FILE
    local status=$?
    set -e
    popd
    # 42 is set in the rspec config for the smoke tests,
    # so we can differentiate between crashes and real failures
    if test $status = 42; then
      echo "Build passed"
      return 0
    else
      echo "Build failed"
      return 1
    fi
  fi;
}

function run_cukes {
  if [ -d features ]; then
    # force jRuby to use client mode JVM or a compilation mode thats as close as possible,
    # idea taken from https://github.com/jruby/jruby/wiki/Improving-startup-time
    #
    # Note that we delay setting this until we run the cukes because we've seen
    # spec failures in our spec suite due to problems with this mode.
    export JAVA_OPTS='-client -XX:+TieredCompilation -XX:TieredStopAtLevel=1'

    if is_mri_192; then
      # For some reason we get SystemStackError on 1.9.2 when using
      # the bin/cucumber approach below. That approach is faster
      # (as it avoids the bundler tax), so we use it on rubies where we can.
      bundle exec cucumber --strict
    else
      # Prepare RUBYOPT for scenarios that are shelling out to ruby,
      # and PATH for those that are using `rspec` or `rake`.
      RUBYOPT="-I${PWD}/../bundle -rbundler/setup" \
         PATH="${PWD}/bin:$PATH" \
         bin/cucumber --strict
    fi
  fi
}

function check_documentation_coverage {
  bin/yard stats --list-undoc | ruby -e "
    while line = gets
      coverage ||= line[/([\d\.]+)% documented/, 1]
      puts line
    end

    unless Float(coverage) == 100
      puts \"\n\nMissing documentation coverage (currently at #{coverage}%)\"
      exit(1)
    end
  "
}
