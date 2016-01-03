package UserAgent;

use LWP::UserAgent;
use LWP::UserAgent::Proxified;
use LWP::UserAgent::Determined;
use LWP::UserAgent::Cached;

use composition "LWP::UserAgent"             =>
                "LWP::UserAgent::Proxified"  =>
                "LWP::UserAgent::Determined" =>
                "LWP::UserAgent::Cached";

@ISA = "LWP::UserAgent::Cached";

1;
