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

sub cgi_auth {
	my ($q) = @_;

	my $api_key = hynsphax_config('phaxio_api_key');
	defined($api_key) or
		cgi_fail('Internal error', 'no phaxio_api_key configured');

	my $api_secret = hynsphax_config('phaxio_api_secret');
	defined($api_secret) or
		cgi_fail('Internal error', 'no phaxio_api_secret configured');

	my $q_api_key = $q->param('api_key') // $q->url_param('api_key');
	if (!defined($q_api_key) || $q_api_key ne $api_key) {
		cgi_fail('The api key you provided does not exist.',
		     defined($q_api_key) ?  "bad api key - $q_api_key" : 'no api key in request');
	}

	my $q_api_secret = $q->param('api_secret') // $q->url_param('api_secret');
	defined($q_api_secret) or
		cgi_fail('You must provide API credentials for this operation.',
			 'no api secret in request');

	$q_api_secret eq $api_secret or
		cgi_fail('The api credentials you provided are invalid.',
		"invalid api secret - $q_api_secret");

	return ($api_key, $api_secret);
}

sub cgi_fail {
	my ($message, $log) = @_;

	{ no if $] >= 5.022, q|warnings|, qw(redundant);
	_log("error: " . sprintf($log, $message));
	}

	print "status: 400\nContent-type: application/json\n\n";
	print '{"success":false,"message":"' . json_escape($message) . '"}' . "\n";

	exit(1);
}

1;
