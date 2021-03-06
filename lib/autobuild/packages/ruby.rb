module Autobuild
    class Ruby < ImporterPackage
        # The Rake task that is used to set up the package. Defaults to "default".
        # Set to nil to disable setup altogether
        attr_accessor :rake_setup_task
        # The Rake task that is used to generate documentation. Defaults to "doc".
        # Set to nil to disable documentation generation
        attr_accessor :rake_doc_task
        # The Rake task that is used to run tests. Defaults to "test".
        # Set to nil to disable tests for this package
        attr_accessor :rake_test_task
        # The Rake task that is used to run cleanup. Defaults to "clean".
        # Set to nil to disable tests for this package
        attr_accessor :rake_clean_task

        def initialize(*args)
            self.rake_setup_task = "default"
            self.rake_doc_task   = "redocs"
            self.rake_clean_task   = "clean"
            self.rake_test_task  = "test"

            super
            exclude << /\.so$/
            exclude << /Makefile$/
            exclude << /mkmf.log$/
            exclude << /\.o$/
            exclude << /doc$/
        end

        def with_doc
            doc_task do
                progress_start "generating documentation for %s", :done_message => 'generated documentation for %s' do
                    Autobuild::Subprocess.run self, 'doc',
                        Autobuild.tool_in_path('ruby'), '-S', Autobuild.tool('rake'), rake_doc_task,
                        :working_directory => srcdir
                end
            end
        end

        def with_tests
            test_utility.task do
                progress_start "running tests for %s", :done_message => 'tests passed for %s' do
                    Autobuild::Subprocess.run self, 'test',
                        Autobuild.tool_in_path('ruby'), '-S', Autobuild.tool('rake'), rake_test_task,
                        :working_directory => srcdir
                end
            end
        end

        def invoke_rake(setup_task = rake_setup_task)
            if setup_task && File.file?(File.join(srcdir, 'Rakefile'))
                Autobuild::Subprocess.run self, 'post-install',
                    Autobuild.tool_in_path('ruby'), '-S', Autobuild.tool('rake'), setup_task,
                    :working_directory => srcdir
            end
        end

        def install
            progress_start "setting up Ruby package %s", :done_message => 'set up Ruby package %s' do
                Autobuild.update_environment srcdir
                # Add lib/ unconditionally, as we know that it is a ruby package.
                # update_environment will add it only if there is a .rb file in the directory
                libdir = File.join(srcdir, 'lib')
                if File.directory?(libdir)
                    Autobuild.env_add_path 'RUBYLIB', libdir
                end

                invoke_rake
            end
            super
        end

        def prepare_for_forced_build # :nodoc:
            super
            %w{ext tmp}.each do |extdir|
                if File.directory?(extdir)
                    Find.find(extdir) do |file|
                        next if file !~ /\<Makefile\>|\<CMakeCache.txt\>$/
                        FileUtils.rm_rf file
                    end
                end
            end
        end

        def prepare_for_rebuild # :nodoc:
            super
            if rake_clean_task && File.file?(File.join(srcdir, 'Rakefile'))
                begin
                    Autobuild::Subprocess.run self, 'clean',
                        Autobuild.tool_in_path('ruby'), '-S', Autobuild.tool('rake'), rake_clean_task,
                        :working_directory => srcdir
                rescue Autobuild::SubcommandFailed => e
                    warn "%s: cleaning failed. If this package does not need a clean target,"
                    warn "%s: set pkg.rake_clean_task = nil in the package definition."
                    warn "%s: see #{e.logfile} for more details"
                end
            end
        end

        def update_environment
            Autobuild.update_environment srcdir
            libdir = File.join(srcdir, 'lib')
            if File.directory?(libdir)
                Autobuild.env_add_path 'RUBYLIB', libdir
            end
        end
    end

    def self.ruby(spec, &proc)
        Ruby.new(spec, &proc)
    end
end

