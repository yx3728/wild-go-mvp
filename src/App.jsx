import { useMemo, useState } from "react";
import Tilt from "react-parallax-tilt";
import { FoilOverlay } from "card-foil/react";
import "card-foil/style.css";
import {
  Activity,
  ArrowLeft,
  BadgeCheck,
  Bell,
  Binoculars,
  BookOpen,
  Camera,
  ChevronDown,
  Compass,
  Eye,
  Filter,
  Grid2X2,
  Hand,
  HeartHandshake,
  Layers3,
  Leaf,
  List,
  LockKeyhole,
  MapPin,
  PanelsTopLeft,
  RotateCcw,
  Route,
  ScanLine,
  Send,
  Share2,
  ShieldCheck,
  Sparkles,
  Star,
  Trophy,
  UserRound,
  Users,
  WalletCards,
  Zap,
} from "lucide-react";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

const collectionProgress = 49;

const cards = [
  {
    id: "blue-jay",
    name: "Blue Jay",
    latin: "Cyanocitta cristata",
    image: "/assets/capture-blue-jay-gen.png",
    stars: 6,
    rarity: "City Legend",
    finish: "Holo Foil",
    confidence: 92,
    location: "Prospect Park",
    date: "Jul 4, 2026",
    privacy: "Approx location",
    serial: "#WGO-26-0704-1178",
    note: "Bold, noisy, and usually spotted near mature street trees.",
    tone: "legend",
  },
  {
    id: "cardinal",
    name: "Northern Cardinal",
    latin: "Cardinalis cardinalis",
    image: "/assets/binder-cardinal-gen.png",
    stars: 6,
    rarity: "City Legend",
    finish: "Holo Foil",
    confidence: 94,
    location: "Brooklyn, NY",
    date: "Jul 4, 2026",
    privacy: "Approx location",
    serial: "#WGO-26-0704-1220",
    note: "A bright neighborhood trophy card with a strong seasonal signal.",
    tone: "legend",
  },
  {
    id: "squirrel",
    name: "Eastern Gray Squirrel",
    latin: "Sciurus carolinensis",
    image: "/assets/binder-squirrel-gen.png",
    stars: 3,
    rarity: "Rare",
    finish: "Metallic",
    confidence: 86,
    location: "Prospect Park",
    date: "Jul 1, 2026",
    privacy: "City level",
    serial: "#WGO-26-0701-0812",
    note: "Fast park regular. Look for fence lines and old oaks.",
    tone: "rare",
  },
  {
    id: "pigeon",
    name: "Rock Pigeon",
    latin: "Columba livia",
    image: "/assets/binder-pigeon-gen.png",
    stars: 1,
    rarity: "Common",
    finish: "Matte",
    confidence: 90,
    location: "Williamsburg",
    date: "Jun 30, 2026",
    privacy: "Public area",
    serial: "#WGO-26-0630-0921",
    note: "The everyday city classic, found around plazas and rooftops.",
    tone: "common",
  },
  {
    id: "flower",
    name: "Black-eyed Susan",
    latin: "Rudbeckia hirta",
    image: "/assets/binder-flower-gen.png",
    stars: 2,
    rarity: "Uncommon",
    finish: "Colored Edge",
    confidence: 88,
    location: "Fort Greene Park",
    date: "Jul 2, 2026",
    privacy: "Public area",
    serial: "#WGO-26-0702-1104",
    note: "A sunny summer find along paths and open garden beds.",
    tone: "uncommon",
  },
  {
    id: "butterfly",
    name: "Monarch Butterfly",
    latin: "Danaus plexippus",
    image: "/assets/binder-butterfly-gen.png",
    stars: 4,
    rarity: "Seasonal",
    finish: "Iridescent",
    confidence: 91,
    location: "Brooklyn Botanic Garden",
    date: "Jun 28, 2026",
    privacy: "Approx location",
    serial: "#WGO-26-0628-0755",
    note: "A high-value seasonal card. Best near milkweed and asters.",
    tone: "seasonal",
  },
  {
    id: "turkey-tail",
    name: "Turkey Tail",
    latin: "Trametes versicolor",
    image: "/assets/binder-turkey-tail-gen.png",
    stars: 5,
    rarity: "Local Special",
    finish: "Foil",
    confidence: 83,
    location: "Greenpoint",
    date: "Jun 27, 2026",
    privacy: "Softened",
    serial: "#WGO-26-0627-0990",
    note: "Appears after rain near older trunks and leaf litter.",
    tone: "special",
  },
];

const friendActivity = [
  {
    name: "Maya",
    avatar: "/assets/friends-maya-gen.png",
    action: "unlocked a 4-Star",
    species: "Monarch Butterfly",
    location: "Prospect Park",
    time: "2h ago",
    reward: "+50 XP",
    image: "/assets/friends-butterfly-gen.png",
  },
  {
    name: "Leo",
    avatar: "/assets/friends-leo-gen.png",
    action: "added a new card",
    species: "Honey Mushroom",
    location: "Bushwick",
    time: "3h ago",
    reward: "+20 XP",
    image: "/assets/friends-mushroom-gen.png",
  },
];

const navItems = [
  { id: "explore", label: "Explore", icon: Compass },
  { id: "map", label: "Map", icon: MapPin },
  { id: "capture", label: "Capture", icon: Camera, primary: true },
  { id: "cards", label: "Binder", icon: WalletCards },
  { id: "profile", label: "Profile", icon: UserRound },
];

const rarityFilters = ["All", "1-2", "3-4", "5-6"];

function cn(...classes) {
  return classes.filter(Boolean).join(" ");
}

function Stars({ count, className = "" }) {
  return (
    <span className={cn("wg-stars", className)} aria-label={`${count} star rarity`}>
      {Array.from({ length: 6 }).map((_, index) => (
        <Star
          key={index}
          className={index < count ? "is-filled" : ""}
          size={14}
          strokeWidth={2.25}
        />
      ))}
    </span>
  );
}

function IconButton({ label, children, className = "", ...props }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button
          type="button"
          variant="secondary"
          size="icon"
          className={cn("h-9 w-9 rounded-full bg-white/82 text-zinc-950 shadow-sm backdrop-blur", className)}
          aria-label={label}
          {...props}
        >
          {children}
        </Button>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}

function PhoneTopBar({ title, subtitle, dark = false, back = false }) {
  return (
    <header className={cn("wg-topbar", dark && "is-dark")}>
      <div className="flex min-w-0 items-center gap-2">
        {back && (
          <IconButton label="Back" className="bg-black/26 text-white ring-1 ring-white/20">
            <ArrowLeft size={18} />
          </IconButton>
        )}
        <div className="min-w-0">
          <p className="wg-brand">
            <Leaf size={17} strokeWidth={2.4} />
            Wild Go
          </p>
          <h1>{title}</h1>
          {subtitle && <span>{subtitle}</span>}
        </div>
      </div>
      <div className="flex items-center gap-2">
        <Badge variant="secondary" className="rounded-full bg-white/80 px-2.5 text-[11px] text-zinc-900">
          Lv. 23
        </Badge>
        <IconButton label="Notifications" className={dark ? "bg-white/16 text-white ring-1 ring-white/20" : ""}>
          <Bell size={18} />
        </IconButton>
      </div>
    </header>
  );
}

function CollectionRail({ compact = false }) {
  return (
    <Card className={cn("wg-collection-card", compact && "is-compact")}>
      <CardContent className="grid gap-3 p-3">
        <div className="flex items-center justify-between gap-3">
          <div className="min-w-0">
            <p>NYC Collection</p>
            <strong>243 / 500 species</strong>
          </div>
          <Badge variant="outline" className="rounded-full bg-white">
            <ChevronDown size={13} />
            49%
          </Badge>
        </div>
        <Progress value={collectionProgress} className="h-2" />
      </CardContent>
    </Card>
  );
}

function TradingCard({ card, variant = "standard", className = "" }) {
  const isHero = variant === "hero";
  const isMini = variant === "mini";
  const isLegend = card.stars >= 6;
  const finish = isLegend ? "oil-slick" : card.stars >= 5 ? "foil" : card.stars >= 4 ? "galaxy" : "etched";
  const intensity = isLegend ? 1.2 : card.stars >= 5 ? 0.82 : card.stars >= 4 ? 0.52 : card.stars >= 3 ? 0.26 : 0;

  return (
    <Tilt
      className={cn("wg-trading-card-shell", variant, className)}
      tiltEnable={!isMini}
      tiltReverse
      tiltMaxAngleX={isHero ? 11 : 5}
      tiltMaxAngleY={isHero ? 13 : 6}
      perspective={900}
      scale={isHero ? 1.01 : 1}
      glareEnable={isHero || isLegend}
      glareMaxOpacity={0.12}
      glareColor="#ffffff"
      glarePosition="all"
      glareBorderRadius={isHero ? "24px" : "18px"}
    >
      <article className={cn("wg-trading-card", card.tone, variant)}>
        <div className="wg-card-chrome">
          <div className="flex items-center justify-between gap-2">
            <Badge className="rounded-full bg-black text-white shadow-sm">
              {card.rarity}
            </Badge>
            <Stars count={card.stars} />
          </div>

          <div className="wg-card-media">
            <img src={card.image} alt="" />
            <span className="wg-card-location">
              <MapPin size={13} />
              {card.privacy}
              <ShieldCheck size={13} />
            </span>
          </div>

          <div className="wg-card-copy">
            <div>
              <h2>{card.name}</h2>
              <p>{card.latin}</p>
            </div>
            {!isMini && (
              <Badge variant="outline" className="rounded-full bg-white/75">
                {card.finish}
              </Badge>
            )}
          </div>

          {!isMini && (
            <div className="wg-card-meta">
              <span>
                <small>AI match</small>
                <strong>{card.confidence}%</strong>
              </span>
              <span>
                <small>First seen</small>
                <strong>{card.date}</strong>
              </span>
            </div>
          )}

          {isHero && (
            <div className="wg-card-footerline">
              <span>{card.serial}</span>
              <span>{card.location}</span>
            </div>
          )}
        </div>

        {intensity > 0 && (
          <FoilOverlay finish={finish} intensity={intensity} tilt={false} specular shimmer={isLegend} />
        )}
      </article>
    </Tilt>
  );
}

function CaptureView({ setActiveView }) {
  const [saved, setSaved] = useState(false);
  const [motionEnabled, setMotionEnabled] = useState(false);
  const captureCard = cards[0];

  async function enableMotion() {
    const orientation = window.DeviceOrientationEvent;
    if (orientation?.requestPermission) {
      const result = await orientation.requestPermission();
      setMotionEnabled(result === "granted");
      return;
    }

    setMotionEnabled(true);
  }

  return (
    <section className="wg-view wg-capture">
      <PhoneTopBar title="New card unlocked" subtitle="Move phone to catch foil" dark back />

      <div className="wg-capture-hero">
        <div className="wg-unlock-copy">
          <Badge className="rounded-full bg-amber-300 text-zinc-950">
            <Sparkles size={13} />
            6-Star Holo
          </Badge>
          <h2>Blue Jay captured</h2>
          <p>Wild Go turns your real observation into a collectible, privacy-safe card.</p>
        </div>

        <TradingCard card={captureCard} variant="hero" />
      </div>

      <div className="wg-action-grid">
        <Button type="button" size="lg" className="h-12 rounded-2xl" onClick={() => setSaved(true)}>
          <BookOpen size={18} />
          {saved ? "Added to Binder" : "Add to Binder"}
        </Button>
        <Button type="button" size="lg" variant="secondary" className="h-12 rounded-2xl">
          <Share2 size={18} />
          Share Card
        </Button>
      </div>

      <Card className="wg-control-card">
        <CardContent className="grid grid-cols-3 gap-2 p-2">
          {[
            [RotateCcw, "Tilt", motionEnabled ? "Live motion" : "Catch foil", enableMotion],
            [Hand, "Press", "Feel depth"],
            [Eye, "Inspect", "Card back"],
          ].map(([Icon, label, body, handler]) => (
            <Button
              key={label}
              type="button"
              variant="ghost"
              className="h-auto flex-col gap-1 rounded-xl px-2 py-3"
              onClick={handler}
            >
              <Icon size={19} />
              <strong>{label}</strong>
              <span>{body}</span>
            </Button>
          ))}
        </CardContent>
      </Card>

      <Button
        type="button"
        variant="link"
        className="mx-auto text-white/80"
        onClick={() => setActiveView("cards")}
      >
        Open binder
      </Button>
    </section>
  );
}

function BinderView({ setActiveView }) {
  const [filter, setFilter] = useState("All");
  const filteredCards = useMemo(() => {
    if (filter === "All") return cards.slice(1);
    const [min, max] = filter.split("-").map(Number);
    return cards.filter((card) => card.stars >= min && card.stars <= max);
  }, [filter]);

  return (
    <section className="wg-view wg-binder">
      <PhoneTopBar title="My Binder" subtitle="134 cards collected" />

      <CollectionRail />

      <Tabs value="binder" className="wg-tabs">
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="binder">
            <BookOpen size={15} />
            Binder
          </TabsTrigger>
          <TabsTrigger value="stacks">
            <Layers3 size={15} />
            Stacks
          </TabsTrigger>
          <TabsTrigger value="missions">
            <Trophy size={15} />
            Goals
          </TabsTrigger>
          <TabsTrigger value="friends" onClick={() => setActiveView("friends")}>
            <Users size={15} />
            Friends
          </TabsTrigger>
        </TabsList>
      </Tabs>

      <div className="wg-toolbar">
        <Button variant="outline" size="sm" className="rounded-full bg-white">
          <Filter size={14} />
          Recent
        </Button>
        <div className="flex gap-1">
          <Button variant="secondary" size="icon-sm" className="rounded-full">
            <Grid2X2 size={15} />
          </Button>
          <Button variant="ghost" size="icon-sm" className="rounded-full">
            <List size={16} />
          </Button>
        </div>
      </div>

      <div className="wg-filter-row">
        {rarityFilters.map((item) => (
          <Button
            key={item}
            type="button"
            variant={filter === item ? "default" : "outline"}
            size="sm"
            className="rounded-full"
            onClick={() => setFilter(item)}
          >
            {item}
          </Button>
        ))}
      </div>

      <div className="wg-binder-board">
        <TradingCard card={cards[1]} variant="feature" />
        <div className="wg-binder-side">
          {filteredCards.slice(0, 4).map((card) => (
            <TradingCard key={card.id} card={card} variant="mini" />
          ))}
        </div>
      </div>

      <Card className="wg-rarity-guide">
        <CardHeader className="pb-2">
          <CardTitle>Rarity Guide</CardTitle>
          <CardDescription>Discovery difficulty maps to card finish.</CardDescription>
        </CardHeader>
        <CardContent className="grid grid-cols-3 gap-2">
          {[
            ["1", "Common", "Matte"],
            ["2", "Uncommon", "Colored"],
            ["3", "Rare", "Metallic"],
            ["4", "Seasonal", "Iridescent"],
            ["5", "Local Special", "Foil"],
            ["6", "City Legend", "Holo"],
          ].map(([stars, label, finish]) => (
            <div key={stars} className="wg-rarity-cell">
              <strong>{stars}</strong>
              <span>{label}</span>
              <small>{finish}</small>
            </div>
          ))}
        </CardContent>
      </Card>
    </section>
  );
}

function FriendsView() {
  const [showcased, setShowcased] = useState(false);

  return (
    <section className="wg-view wg-friends">
      <PhoneTopBar title="Friends' Finds" subtitle="2 new showcases today" />

      <Card className="wg-profile-strip">
        <CardContent className="flex items-center gap-3 p-3">
          <Avatar className="h-12 w-12">
            <AvatarImage src="/assets/friends-leo-gen.png" alt="" />
            <AvatarFallback>J</AvatarFallback>
          </Avatar>
          <div className="min-w-0 flex-1">
            <strong>Level 24 City Explorer</strong>
            <Progress value={76} className="mt-2 h-2" />
            <span>2,340 / 3,000 XP</span>
          </div>
          <Badge variant="secondary" className="shrink-0 rounded-full">
            <WalletCards size={14} />
            248
          </Badge>
        </CardContent>
      </Card>

      <div className={cn("wg-showcase", showcased && "is-showcased")}>
        <TradingCard card={{ ...cards[4], name: "Oxeye Daisy", latin: "Leucanthemum vulgare" }} variant="stack back" />
        <TradingCard card={cards[2]} variant="stack mid" />
        <TradingCard card={cards[1]} variant="stack front" />
      </div>

      <div className="wg-action-grid">
        <Button type="button" className="h-11 rounded-2xl" onClick={() => setShowcased((value) => !value)}>
          <Sparkles size={18} />
          {showcased ? "Showcase Live" : "Showcase"}
        </Button>
        <Button type="button" variant="secondary" className="h-11 rounded-2xl">
          <HeartHandshake size={18} />
          Trade Later
        </Button>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Friend Activity</CardTitle>
              <CardDescription>Recent cards from your circle.</CardDescription>
            </div>
            <Button variant="ghost" size="sm" className="rounded-full">
              See all
            </Button>
          </div>
        </CardHeader>
        <CardContent className="grid gap-3">
          {friendActivity.map((item) => (
            <article key={item.name} className="wg-friend-row">
              <Avatar className="h-10 w-10">
                <AvatarImage src={item.avatar} alt="" />
                <AvatarFallback>{item.name[0]}</AvatarFallback>
              </Avatar>
              <div className="min-w-0 flex-1">
                <strong>
                  {item.name} {item.action}
                </strong>
                <span>{item.species}</span>
                <small>{item.location} · {item.time}</small>
              </div>
              <img src={item.image} alt="" />
              <Badge variant="secondary" className="rounded-full">
                {item.reward}
              </Badge>
            </article>
          ))}
        </CardContent>
      </Card>

      <div className="wg-social-rail">
        <Button variant="ghost" className="flex-1">
          <Send size={18} />
          Send
        </Button>
        <Button variant="ghost" className="flex-1">
          <PanelsTopLeft size={18} />
          Compare
        </Button>
        <Button className="h-12 w-12 rounded-full">
          <Camera size={22} />
        </Button>
      </div>
    </section>
  );
}

function ExploreView() {
  return (
    <section className="wg-view wg-plain">
      <PhoneTopBar title="Today nearby" subtitle="Short quests for real walks" />

      <Card className="wg-hero-panel">
        <CardHeader>
          <Badge className="w-fit rounded-full">
            <Binoculars size={14} />
            Nearby
          </Badge>
          <CardTitle>Three gentle missions for today</CardTitle>
          <CardDescription>
            Wild Go nudges everyday observation without turning the map into a race.
          </CardDescription>
        </CardHeader>
        <CardContent className="grid gap-2">
          {[
            ["Morning Flyers", "Capture one bird before 10 AM", "2 / 3", Zap],
            ["Yellow Bloom", "Find one yellow flower", "1 / 1", Leaf],
            ["Soft Map", "Record from 2 approximate areas", "1 / 2", Route],
          ].map(([title, body, progress, Icon]) => (
            <button type="button" className="wg-mission-row" key={title}>
              <Icon size={18} />
              <span>
                <strong>{title}</strong>
                <small>{body}</small>
              </span>
              <Badge variant="outline">{progress}</Badge>
            </button>
          ))}
        </CardContent>
      </Card>

      <MapPanel />
    </section>
  );
}

function MapPanel() {
  return (
    <Card className="wg-map-panel">
      <CardContent className="relative h-72 overflow-hidden p-0">
        <div className="wg-map-grid" />
        <span className="wg-pin pin-a">
          <Leaf size={14} />
        </span>
        <span className="wg-pin pin-b">
          <Camera size={14} />
        </span>
        <span className="wg-pin pin-c">
          <ShieldCheck size={14} />
        </span>
        <div className="absolute inset-x-4 bottom-4 rounded-2xl border bg-white/88 p-4 shadow-lg backdrop-blur">
          <Badge variant="secondary" className="mb-2 rounded-full">
            <LockKeyhole size={13} />
            Privacy-safe map
          </Badge>
          <h2>Brooklyn nature map</h2>
          <p>Sensitive finds show approximate neighborhoods by default.</p>
        </div>
      </CardContent>
    </Card>
  );
}

function MapView() {
  return (
    <section className="wg-view wg-plain">
      <PhoneTopBar title="Soft Map" subtitle="Never exact rare-card pins" />
      <MapPanel />
      <Card>
        <CardContent className="grid gap-3 p-4">
          <div className="flex items-center gap-3">
            <div className="wg-icon-disc">
              <ShieldCheck size={18} />
            </div>
            <div>
              <strong>Location softened automatically</strong>
              <p>Rare and sensitive finds are widened to a safer area before sharing.</p>
            </div>
          </div>
          <Separator />
          <div className="flex items-center gap-3">
            <div className="wg-icon-disc">
              <ScanLine size={18} />
            </div>
            <div>
              <strong>Observation first</strong>
              <p>The map supports recall and learning, not exact public collection routes.</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </section>
  );
}

function ProfileView() {
  return (
    <section className="wg-view wg-plain">
      <PhoneTopBar title="City Explorer" subtitle="Level 24" />

      <Card className="wg-profile-card">
        <CardHeader className="items-center text-center">
          <Avatar className="h-20 w-20 ring-4 ring-white">
            <AvatarImage src="/assets/friends-maya-gen.png" alt="" />
            <AvatarFallback>J</AvatarFallback>
          </Avatar>
          <CardTitle>City Explorer</CardTitle>
          <CardDescription>2,340 / 3,000 XP</CardDescription>
        </CardHeader>
        <CardContent className="grid grid-cols-3 gap-2">
          {[
            ["248", "Cards"],
            ["34", "Places"],
            ["6", "Holo"],
          ].map(([value, label]) => (
            <div key={label} className="wg-stat-cell">
              <strong>{value}</strong>
              <span>{label}</span>
            </div>
          ))}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <Badge className="w-fit rounded-full">
            <BadgeCheck size={14} />
            Default safety
          </Badge>
          <CardTitle>Wildlife-safe by default</CardTitle>
          <CardDescription>
            No exact public locations for rare finds. Observe from a distance and keep cards collectible.
          </CardDescription>
        </CardHeader>
        <CardFooter className="gap-2">
          <Button variant="secondary" className="flex-1 rounded-xl">
            <Activity size={16} />
            Activity
          </Button>
          <Button className="flex-1 rounded-xl">
            <Share2 size={16} />
            Share
          </Button>
        </CardFooter>
      </Card>
    </section>
  );
}

function BottomNav({ activeView, setActiveView }) {
  return (
    <nav className="wg-bottom-nav" aria-label="Primary">
      {navItems.map((item) => {
        const Icon = item.icon;
        const isActive = activeView === item.id;
        return (
          <button
            key={item.id}
            type="button"
            className={cn(isActive && "active", item.primary && "primary")}
            onClick={() => setActiveView(item.id)}
          >
            <span>
              <Icon size={item.primary ? 22 : 19} strokeWidth={isActive ? 2.6 : 2.2} />
            </span>
            {item.label}
          </button>
        );
      })}
    </nav>
  );
}

export function App() {
  const [activeView, setActiveViewState] = useState(() => {
    const view = window.location.hash.replace("#", "");
    return ["capture", "cards", "friends", "map", "explore", "profile"].includes(view) ? view : "capture";
  });

  function setActiveView(id) {
    setActiveViewState(id);
    window.history.replaceState(null, "", `#${id}`);
  }

  return (
    <TooltipProvider delayDuration={120}>
      <main className="wg-app-shell">
        <div className={cn("wg-phone", `is-${activeView}`)}>
          {activeView === "capture" && <CaptureView setActiveView={setActiveView} />}
          {activeView === "cards" && <BinderView setActiveView={setActiveView} />}
          {activeView === "friends" && <FriendsView />}
          {activeView === "map" && <MapView />}
          {activeView === "explore" && <ExploreView />}
          {activeView === "profile" && <ProfileView />}

          <BottomNav activeView={activeView} setActiveView={setActiveView} />
        </div>
      </main>
    </TooltipProvider>
  );
}
