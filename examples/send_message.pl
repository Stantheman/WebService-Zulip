#!/usr/bin/env perl
use strict;
use warnings;

use Data::Printer;
use WebService::Zulip;

my $zulip = WebService::Zulip->new(load_zulip_info());

my $result = $zulip->send_message(
	content => 'hi stan from the zulip api',
	to      => 'stan@schwertly.com',
	type    => 'private'
);

p $result;

sub load_zulip_info {
	my $filename = shift || '.zuliprc';
	return unless -e $filename;
	open my $fh, '<', $filename or die "$!";
	{
		local $/ = undef;
		return decode_json(<$fh>);
	}
}