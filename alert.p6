#!/usr/bin/env perl6
use lib <
    /home/zoffix/CPANPRC/IRC-Client/lib
    /home/zoffix/services/lib/IRC-Client/lib
    lib
>;

constant API_URL = "http://content.warframe.com/dynamic/rss.php";

use IRC::Client;
use HTTP::UserAgent;

class WA::Info is IRC::Client::Plugin {
    my %seen;
    multi method irc-started { start {
        %*ENV<WA_DEBUG> or sleep 30; # give a chance to boot
        react {
            whenever Supply.interval(5*60) {
                note "Starting run at {DateTime.now}";
                given HTTP::UserAgent.new.get(API_URL) {
                    when *.is-success.not {
                        note "Failed to fetch API data: {.status-line}";
                        return;
                    }

                    for |.content.match(:g, /'<item>' $<item>=.+? '</item>'/) {
                        next unless $_<item>.Str.contains('Nitain');
                        note "Found Nitain in data!";

                        $_<item>.match: /'<guid>' $<id>=\S+ '</guid>'/;
                        next if %seen{~$<id>}:exists;
                        %seen{~$<id>} = +now;
                        %seen{
                            %seen.grep(*.value < ( now - 3600))».key
                        }:delete;

                        note "Notifying about found Nitain";
                        $.irc.?send: :where<#zofbot> :text("Zoffix, Nitain!!!");
                    }
                }
            }
        }

        CATCH { default { .gist.say } }
    }}
}

# await WA::Info.new.irc-started; exit;

.run with IRC::Client.new:
    :nick<WarframeAlerter>,
    :host(%*ENV<WA_IRC_HOST> // 'irc.freenode.net'),
    :channels<#zofbot>,
    :debug,
    :plugins(
        WA::Info.new,
    );
