# Copyright 2020 Paul B. Henson <henson@acm.org>
#
# hynsphax is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Please see the LICENSE file for further details, or visit the URL
#
#         https://www.gnu.org/licenses/

use strict;
use warnings;

use MIME::Base64 ();

my $fb_options = {
	hyns => {
			allow_reprovision => qr/^(0|1)$/,
			provision_password => qr/^(0|1)$/,
			poll_outbound_status => qr/^(0|1|\((0|1)(,(0|1))+\))$/,
		},
	ata => {
			# Not sure how to validate time zone names
			TimeZoneId => qr/.*/,
			CallAhead => qr/^(Never|Lookup|Always)$/,
			ClientLog => qr/^(Never|OnErrors|Always)$/,
		},
	line => {
			PhoneNumber => qr/^\+?\d+$/,
			StripRowsFromImage => qr/^\d+$/,
			Notifications => qr /^(None|NonDelivery|Delivery|DeliveryAndNonDelivery)$/,
		},
};

sub cgi_auth {
	my ($dbh_config) = @_;

	exists($ENV{HTTP_AUTHORIZATION}) or
		cgi_fail(401, "authentication required", "%s");

	my $authorization = $ENV{HTTP_AUTHORIZATION};
	$authorization =~ s/^Basic // or
		cgi_fail(401, "invalid authentication mechanism", "%s - $authorization");

	$authorization = MIME::Base64::decode($authorization);
	my ($username, $password) = split(/:/, $authorization, 2);

	my $ata = ata_record($dbh_config, 'username', $username);

	defined($ata) or
		cgi_fail(401, "invalid username or password", "%s - username $username not found");

	ref($ata) or
		cgi_fail(500, "internal error", "ata db lookup failed - $ata");

	$ata->{password} eq $password or
		cgi_fail(401, "invalid username or password", "%s - username $username bad password");

	return $ata;
}

sub cgi_fail {
	my ($code, $message, $log) = @_;

	{ no if $] >= 5.022, q|warnings|, qw(redundant);
	_log("error: " . sprintf($log, $message));
	}

	if ($code) {
		print "Status: $code\n";
	}

	print "Content-type: text/plain\n\n";
	print "$message\n";

	exit(1);
}

sub ata_record {
	my ($dbh_config, $key, $value) = @_;

	if ($key !~ /^(mac|username)$/) {
		_log("error: invalid key $key in ata_record");
		return 'invalid key';
	}

	_logd("searching for ata $key = $value");

	my $ata_qh = query($dbh_config,
			   "select * from fb_atas where $key = ? and mac != 'default'",
			   $value);
	$ata_qh or return 'failed to execute ata query';

	my $ata_row = $ata_qh->fetchrow_hashref();
	$ata_row or return undef;

	my $ata_d_qh = query($dbh_config, "select * from fb_atas where mac = 'default'");
	$ata_d_qh or return 'failed to execute ata defaults query';

	my $ata_d_row = $ata_d_qh->fetchrow_hashref();

	my $unknown_option_action = hynsphax_config('fb_unknown_option_action') // 'error';
	_logd("unknown_option_action = $unknown_option_action");

	my %default_options = ( hyns => {
					  allow_reprovision => 0,
					  poll_outbound_status => 1,
					  provision_password => 0,
					},
				ata => {
					 CallAhead => 'Never',
					 ClientLog => 'OnErrors',
				       },
				line => {
					  Notifications => 'None',
					  StripRowsFromImage => 0,
					}
			      );

	if ($ata_d_row) {
		foreach my $type (qw(hyns ata line)) {
			if (defined($ata_d_row->{"${type}_options"})) {
				_logd("processing default $type options");

				foreach my $optpair (split(/,/, $ata_d_row->{"${type}_options"})) {
					my ($opt, $value) = split(/=/, $optpair);

					if (!exists($fb_options->{$type}{$opt})) {
						if ($unknown_option_action =~ /^(error|warning)$/) {
							_log("${1}: invalid default $type option $opt");
							return "invalid option" if $1 eq 'error';
						}
					}
					elsif ($value !~ $fb_options->{$type}{$opt}) {
						if ($unknown_option_action =~ /^(error|warning)$/) {
							_log("${1}: invalid default $type $opt $value");
							return "invalid option value" if $1 eq 'error';
						}
					}

					_logd("setting $opt = $value");
					$default_options{$type}{$opt} = $value;
				}
			}
			else {
				_logd("no default $type options found");
			}
		}
	}
	else {
		_logd("no default ata record found");
	}

	my $ata_record = {
		mac => $ata_row->{mac},
		active => $ata_row->{active},
		provisioned => $ata_row->{provisioned},
		username => $ata_row->{username},
		password => $ata_row->{password},
		hyns_options => $default_options{hyns},
		ata_options => $default_options{ata},
		line_options => [ ],
	};

	foreach my $type (qw(hyns ata)) {
		if (defined($ata_row->{"${type}_options"})) {
			_logd("processing ata $type options");

			foreach my $optpair (split(/,/, $ata_row->{"${type}_options"})) {
				my ($opt, $value) = split(/=/, $optpair);

				if (!exists($fb_options->{$type}{$opt})) {
					if ($unknown_option_action =~ /^(error|warning)$/) {
						_log("${1}: invalid $type option $opt");
							return "invalid option" if $1 eq 'error';
					}
				}
				elsif ($value !~ $fb_options->{$type}{$opt}) {
					if ($unknown_option_action =~ /^(error|warning)$/) {
						_log("${1}: invalid $type $opt $value");
						return "invalid option value" if $1 eq 'error';
					}
				}

				_logd("setting $opt = $value");
				$ata_record->{"${type}_options"}{$opt} = $value;
			}
		}
		else {
			_logd("no ata $type options found");
		}
	}

	my $number_strip_plus = hynsphax_config('fb_number_strip_plus') // 1;
	_logd("number_strip_plus = $number_strip_plus");

	foreach my $line_data (split/\|/, $ata_row->{line_options}) {
		my $line_index = scalar(@{$ata_record->{line_options}});
		_logd("processing ata line $line_index options");

		my $line_record = { Index => $line_index, %{$default_options{line}} };

		foreach my $optpair (split(/,/, $line_data)) {
			my ($opt, $value) = split(/=/, $optpair);

			if (!exists($fb_options->{line}{$opt})) {
				if ($unknown_option_action =~ /^(error|warning)$/) {
					_log("${1}: invalid line option $opt");
						return "invalid option" if $1 eq 'error';
				}
			}
			elsif ($value !~ $fb_options->{line}{$opt}) {
				if ($unknown_option_action =~ /^(error|warning)$/) {
					_log("${1}: invalid line $opt $value");
					return "invalid option value" if $1 eq 'error';
				}
			}

			if ($opt eq 'PhoneNumber' && $value =~ /^\+/ && $number_strip_plus) {
				_logd("stripping + from phone number $value");
				$value =~ s/^\+//;
			}

			_logd("setting $opt = $value");
			$line_record->{$opt} = $value;
		}

		push(@{$ata_record->{line_options}}, $line_record);
	}

	return $ata_record;
}

sub ata_xml {
	my ($ata, $provision_password) = @_;

	_logd("generating ata xml, provision_password = $provision_password");

	my $xml = "<AccountProperties>\n";
	$xml .= "\t<UserName>$ata->{username}</UserName>\n";

	$xml .= "\t<Password>$ata->{password}</Password>\n"
		if $provision_password;

	foreach my $opt (keys %{$ata->{ata_options}}) {
		$xml .= "\t<$opt>$ata->{ata_options}{$opt}</$opt>\n";
	}
	if (!exists($ata->{ata_options}{TimeZoneId})) {
		$xml .= "\t<TimeZoneId null=\"true\" />\n";
	}

	$xml .= "\t<Lines>\n";
	foreach my $line (@{$ata->{line_options}}) {
		$xml .= "\t\t<LineProperties>\n";

		foreach my $opt (keys %{$line}) {
			$xml .= "\t\t\t<$opt>$line->{$opt}</$opt>\n";
		};

		$xml .= "\t\t</LineProperties>\n";
	}
	$xml .= "\t</Lines>\n";

	$xml .= "</AccountProperties>\n";

	return $xml;
}

1;
