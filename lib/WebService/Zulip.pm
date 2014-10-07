package WebService::Zulip;

use strict;
use warnings;

use Carp;
use Encode 'encode_utf8';
use JSON;
use LWP::UserAgent;
use Data::Printer;

our $VERSION = '0.01';

my $api_endpoint = 'https://api.zulip.com/v1/';
my $http_realm   = 'zulip';

sub new {
    my ($package, %args) = @_;
    my $self;

    $self->{_api_key}  = $args{api_key};
    $self->{_api_user} = $args{api_user};
    $self->{_ua} = LWP::UserAgent->new(agent => "WebService::Zulip v $VERSION");
    $self->{_ua}->credentials(
        'api.zulip.com:443',
        $http_realm,
        $self->{_api_user},
        $self->{_api_key},
    );

    bless $self, $package;
    return $self;
}

sub send_message {
    my ($self, %args) = @_;
    # hash is convenient for user, vars is easier to read here
    my ($type, $content, $to, $subject) = @args{'type','content','to','subject'};

    # type: "One of {private, stream}"
    unless (defined($type) && ($type eq 'private' || $type eq 'stream')) {
        croak q{"type" is required and must be either "private" or "stream"};
    }
    # content: "The content of the message. Maximum message size of 10000 bytes."
    my $content_limit = 10000;
    unless (defined($content) && (length(encode_utf8($content)) < $content_limit)) {
        croak qq{"content" is required and must be under $content_limit bytes};
    }
    # to: "In the case of a stream message, a string identifying the stream.
    # In the case of a private message, a JSON-encoded list containing the usernames
    # of the recipients"
    croak q{"to" is required} unless defined($to);
    # either make it a single-element json array, or json_encode the array
    if ($type eq 'private') {
        my $reference = ref($to);
        if ($reference eq '') {
            $to = encode_json([$to]);
        } elsif ($reference eq 'ARRAY') {
            $to = encode_json($to);
        } else {
            print "ref is " . ref($to) . "\n";
            croak q{"to" must either be a string or arrayref in private messages};
        }
    } else {
        # don't allow references/multiple 'to' for stream messages
        if (ref($to)) {
            croak q{"to" must be a string for stream messages};
        }
    }
    # subject: The topic for the message (Only required if type is “stream”).
    # Maximum length of 60 characters.
    if (defined($subject) && $type eq 'private') {
        carp q{"subject" is ignored in private messages};
    }
    if (defined($subject) && length($subject) > 60) {
        croak q{"subject" cannot be over 60 characters};
    }

    my $res = $self->{_ua}->post($api_endpoint . 'messages', {
        type    => $type,
        content => $content,
        to      => $to,
        subject => $subject,
    });

    if ($res->is_error) {
        carp q{Couldn't submit message:};
        p $res;
        return;
    }

    my $returned_json = decode_json($res->decoded_content);
    return $returned_json;
}

sub get_message_queue {
    my ($self, %args) = @_;
    my ($event_types, $apply_markdown) = @args{'event_types', 'apply_markdown'};
    # event_types: (optional) A JSON-encoded array indicating which types of
    # events you're interested in. {message, subscriptions, realm_user (changes
    # in the list of users in your realm), and pointer (changes in your pointer).
    # If you do not specify this argument, you will receive all events

    # allow user to provide either scalar or array ref
    my $reference = ref($event_types);
    if (defined($event_types) && $reference eq '') {
        unless ($event_types =~ /^(?:message|subscriptions|realm_user|pointer)$/) {
            croak q{"event_types" must be one of "message", "subscriptions",
                "realm_user", "pointer", or an arrayref of these, or undefined for all.};
        }
        # wrap the scalar in an array
        $event_types = encode_json([$event_types]);
    } elsif ($reference eq 'ARRAY') {
        if (grep { $_ !~ /message|subscriptions|realm_user|pointer/ } @$event_types) {
            croak q{"event_types" must be one of "message", "subscriptions",
                "realm_user", "pointer", or an arrayref of these, or undefined for all.};
        }
        $event_types = encode_json($event_types);
    } elsif (defined($event_types)) {
        croak q{"event_types" must be one of "message", "subscriptions",
                "realm_user", "pointer", or an arrayref of these, or undefined for all.};
    } else {
        # the API expects JSON if event_types is present, easier to specify
        # each than conditionally send event_types in the request
        $event_types = encode_json([qw(message subscriptions realm_user pointer)]);
    }

    # (optional) set to “true” if you would like the content to be rendered in
    # HTML format (by default, the API returns the raw text that the user entered)
    $apply_markdown ||= 'false';

    my $res = $self->{_ua}->post($api_endpoint . 'register', {
        event_types    => $event_types,
        apply_markdown => $apply_markdown,
    });
    if ($res->is_error) {
        croak q{"Couldn't request queue:\n"};
    }

    my $returned_json = decode_json($res->decoded_content);
    return $returned_json;
}

sub get_new_events {
    my ($self, %args) = @_;
    my ($queue_id, $last_event_id, $dont_block) = @args{'queue_id', 'last_event_id', 'dont_block'};
    return unless defined($queue_id) && $queue_id =~ /^[\d:]+$/;
    return unless defined($last_event_id) && $last_event_id =~ /^[\d-]+$/;
    $dont_block ||= 'true';

    # being lazy
    my $res = $self->{_ua}->get($api_endpoint . 'events?' .
        "queue_id=$queue_id&" .
        "last_event_id=$last_event_id&" .
        "dont_block=$dont_block"
    );
    if ($res->is_error) {
        croak qq{Couldn't get events: $res->decoded_content};
    }

    my $returned_json = decode_json($res->decoded_content);
    return $returned_json;
}

sub get_last_event_id {
    my ($self, $events_info) = @_;
    # sigh. this is how they do it in their python module
    my $max_id = 0;
    for my $event (@{$events_info->{events}}) {
        $max_id = $max_id > $event->{id} ? $max_id : $event->{id};
    }
    return $max_id;
}

1;