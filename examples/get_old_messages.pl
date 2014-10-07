#!/usr/bin/env perl
use strict;
use warnings;

use Data::Printer;
use JSON;
use WebService::Zulip;

my $zulip = WebService::Zulip->new(%{load_zulip_info()});

my $queue = load_queue_info($zulip);

my $result = $zulip->get_old_messages();
p $result;

sub load_queue_info {
	my $zulip = shift;
	my $filename = '.zulip-info';
	my $queue;
	if (-e $filename) {
		open my $fh, '<', $filename or die "$!";
		warn "Loaded $filename\n";
		return decode_json(<$fh>);
	} else {
		my $queue = $zulip->get_message_queue();
		open my $fh, '>', $filename or die "$!";
		print $fh encode_json($queue);
		warn "Created new $filename\n";
		return $queue;
	}
}

sub load_zulip_info {
	my $filename = shift || '.zuliprc';
	return unless -e $filename;
	open my $fh, '<', $filename or die "$!";
	{
		local $/ = undef;
		return decode_json(<$fh>);
	}
}