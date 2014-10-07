#!/usr/bin/env perl
use strict;
use warnings;

use Data::Printer;
use JSON;
use WebService::Zulip;

my $zulip = WebService::Zulip->new(%{load_zulip_info()});

my $queue = load_queue_info($zulip);

while (1) {
	my $result = $zulip->get_new_events(
		queue_id      => $queue->{queue_id},
		last_event_id => $queue->{last_event_id},
		dont_block => 'false'
	);
	for my $event (@{$result->{events}}) {
		my $message = $event->{message};
		next if ($event->{type} eq 'heartbeat' || $event->{type} eq 'pointer');
		if ($message->{type} eq 'private') {
			print "$message->{sender_short_name} PMed you: $message->{content}\n";
			next;
		}
		print "$message->{sender_short_name} in $message->{display_recipient}: $message->{content}\n";
	}
	$queue->{last_event_id} = $zulip->get_last_event_id($result);
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