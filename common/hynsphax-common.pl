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

use Unix::Syslog ();

my $debug = 0;

sub _log_debug {
	($debug) = @_;
}

sub _log {
	my ($message) = @_;

	Unix::Syslog::syslog(Unix::Syslog::LOG_NOTICE, "%s", $message);
}

sub _logd {
	my ($message, $level) = @_;
	$level //= 1;

	return unless $debug >= $level;

	_log($message);
}

sub _logp {
	my ($message) = @_;

	print "$message\n";
	_log($message);
}

sub safe_pipe {
	my ($command, @options) = @_;

	my $fh;
	my $pid = open($fh, "-|");
	if (defined($pid)) {
		if ($pid) {
			return $fh;
		}
		else {
			open(STDERR, ">&STDOUT");
			exec($command, @options);
			exit(1);
		}
	}

	return;
}

sub read_pipe {
	my @args = @_;

	my @output;

	my $fh = safe_pipe(@args);

	if (!$fh) {
		return (-1, \@output);
	}

	while (<$fh>) {
		chomp;
		push(@output, $_);
	}

	if (!close($fh) || $? != 0) {
		return (0, \@output);
	}

	return (1, \@output);
}

sub dbi_connect {
	my ($db_servers) = @_;
	my $dbh;

	foreach (@{$db_servers}) {
		my ($ds, $user, $password, $options) = @{$_};

		$dbh = DBI->connect($ds, $user, $password, $options) and last;

		_log("warning: failed to connect to $ds - $DBI::errstr");
	}

	return $dbh;
}

sub query {
	my ($dbh, $q, @args) = @_;
	my $qh;

	if (ref($q)) {
		$qh = $q;
	}
	else {
		$qh = $dbh->prepare($q);

		if (!$qh) {
			_log("error: failed to parse sql $q - $DBI::errstr");
			return;
		}

		return $qh if wantarray;
	}

	if (!$qh->execute(@args)) {
		_log("error: failed to execute query - $DBI::errstr");
		return;
	}

	return $qh;
}

sub json_escape {
	my ($string) = @_;

	$string =~ s/\\/\\\\/g;
	$string =~ s/"/\\"/g;
	$string =~ s#/#\\/#g;
	$string =~ s/[\b]/\\b/g;
	$string =~ s/\f/\\f/g;
	$string =~ s/\n/\\n/g;
	$string =~ s/\r/\\r/g;
	$string =~ s/\t/\\t/g;

	return $string;
}

sub var_swap {
	my ($vars, $val) = @_;

	while ($val =~ /(^|[^\\])\$\{([^}]+)}/) {
		my ($lead_char, $var_name) = ($1, $2);
		my $sub;
		if (exists($vars->{$var_name})) {
			_logd("replacing var $var_name with $vars->{$var_name}");
			$sub = $vars->{$var_name};
		}
		else {
			_log("warning: var $var_name not defined, using empty string");
			$sub = '';
		}
		$val =~ s/\Q${lead_char}\E\${\Q${var_name}\E}/${lead_char}${sub}/;
	}

	return $val;
}

1;
