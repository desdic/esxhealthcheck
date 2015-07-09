#!/usr/bin/perl -w
# Simple health check (Sysorb) for ESXi by Kim Nielsen

use Data::Dumper;
use POSIX;
use strict;
use warnings;
use FindBin;
use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIRuntime;
use VMware::VIFPLib;
use VMware::VmaTargetLib;

$Util::script_version = "1.0";

my %opts = (
        debug => {
        type => "!",
        help => "Turn debugging on",
        required => 0,
        },
);

eval {
	# Setup signal handler to give timeout result
	local $SIG{ALRM} = sub { die "Result: 255\n" };

	# Set a timeout for the script
	alarm 60;

	Opts::add_options(%opts);
	Opts::parse();
	Opts::validate();

	my $server = Opts::get_option('server');
	VIFPLib::login_by_fastpass($server);

	Util::connect();
	healthcheck();
	Util::disconnect();

	alarm 0;
};

if ($@) {
	# Default result if something failed
	print "Result: 255\n";
}

sub healthcheck {

	my $warnings=0;
	my $errors=0;

	my $hostViews = Vim::find_entity_views(view_type => 'HostSystem' );

	foreach my $local_host (@$hostViews) {

		# Hardware check
		if(defined($local_host->runtime->healthSystemRuntime)) {
                        my $sensors = $local_host->runtime->healthSystemRuntime->systemHealthInfo->numericSensorInfo;
                        foreach(@$sensors) {
                                my $sensor_health = $_->healthState->key;

				if( Opts::option_is_set('debug') ) {
					print "\"".$_->name."\" ";
				}

				my $status='Unknown';
				if ($sensor_health eq 'yellow' || !$sensor_health eq 'Yellow') {
					$status="Warning";
					$warnings++;
				} elsif ($sensor_health eq 'red' || !$sensor_health eq 'Red') {
					$status="Error";
					$errors++;
				}
				else {
					$status="OK";
				}

				if( Opts::option_is_set('debug') ) {
					print "[".$status."]\n";
				}
			}
		}
	}

	if( Opts::option_is_set('debug') ) {
		print "--------------------------------\n";
		print "Summery:\n";
		print "--------------------------------\n";

		if ($errors gt 0) {
			print "Errors: ".$errors."\n";
		}

		if ($warnings gt 0) {
			print "Warnings: ".$warnings."\n";
		}
	}

	if ($errors gt 0) {
		print "Result: 2\n";
	}
	elsif ($warnings gt 0) {
		print "Result: 1\n";
	} else {
		print "Result: 0\n";
	}
}

__END__
