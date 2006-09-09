use Module::Build;
# See perldoc Module::Build for details of how this works

Module::Build->new
    ( module_name     => 'File::RandomLine',
      create_makefile_pl => 'traditional',
      create_readme => 1,
      license         => 'perl',
      requires => {
          perl => 5.006,
          Want => 0.08,
      },
      build_requires => {
          File::Spec => 0.87, # (0.6 since perl 5.005, 0.87 since perl 5.008003)
          Test::Exception => 0.20,
          Test::More => 0.6, # (0.41 since perl 5.007003, 0.6 is new)
          Test::MockRandom => 0.97,
          Test::Warn => 0.08,
      },
	)->create_build_script;
