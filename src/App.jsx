import { useMemo, useState } from "react";
import Tilt from "react-parallax-tilt";
import { FoilOverlay } from "card-foil/react";
import "card-foil/style.css";
import {
  ArrowLeft,
  Binoculars,
  Bell,
  BookOpen,
  Camera,
  Cards,
  CaretDown,
  Compass,
  Flag,
  FunnelSimple,
  GridFour,
  Handshake,
  HandTap,
  Info,
  Leaf,
  ListBullets,
  LockKey,
  MapPin,
  PaperPlaneTilt,
  PawPrint,
  ShareFat,
  Sparkle,
  Stack,
  Star,
  Swap,
  UserCircle,
  Users,
} from "@phosphor-icons/react";

const cardData = [
  {
    id: "blue-jay",
    name: "Blue Jay",
    latin: "Cyanocitta cristata",
    image: "/assets/blue-jay.png",
    stars: 6,
    rarity: "City Legend",
    finish: "Holo Foil",
    confidence: 92,
    location: "Prospect Park",
    date: "Jul 4, 2026",
    privacy: "Approx location",
    note: "Bold, noisy, and usually spotted near mature street trees.",
    className: "legendary",
  },
  {
    id: "rock-pigeon",
    name: "Rock Pigeon",
    latin: "Columba livia",
    image: "/assets/rock-pigeon.png",
    stars: 1,
    rarity: "Common",
    finish: "Matte",
    confidence: 96,
    location: "Downtown curb",
    date: "Jul 1",
    privacy: "Public area",
    note: "The everyday city classic. Best seen around plazas, rooftops, and train stations.",
    className: "common",
  },
  {
    id: "squirrel",
    name: "Eastern Gray Squirrel",
    latin: "Sciurus carolinensis",
    image: "/assets/squirrel.png",
    stars: 3,
    rarity: "Rare",
    finish: "Metallic",
    confidence: 86,
    location: "Grand Army Plaza",
    date: "Jul 2",
    privacy: "City level",
    note: "Fast park regular. Look for fence lines and old oaks.",
    className: "rare",
  },
  {
    id: "flower",
    name: "Black-eyed Susan",
    latin: "Rudbeckia hirta",
    image: "/assets/flower.png",
    stars: 2,
    rarity: "Uncommon",
    finish: "Colored edge",
    confidence: 88,
    location: "Fort Greene",
    date: "Jul 2",
    privacy: "Public area",
    note: "A sunny summer find along paths and open garden beds.",
    className: "uncommon",
  },
  {
    id: "butterfly",
    name: "Monarch Butterfly",
    latin: "Danaus plexippus",
    image: "/assets/butterfly.png",
    stars: 5,
    rarity: "Local Special",
    finish: "Foil",
    confidence: 91,
    location: "Botanic Garden",
    date: "Jun 28",
    privacy: "Approx location",
    note: "A high-value seasonal card. Best near milkweed and asters.",
    className: "special",
  },
  {
    id: "mushroom",
    name: "Honey Mushroom",
    latin: "Armillaria mellea",
    image: "/assets/mushroom.png",
    stars: 4,
    rarity: "Seasonal",
    finish: "Iridescent",
    confidence: 83,
    location: "Greenpoint",
    date: "Jun 27",
    privacy: "Softened",
    note: "Appears after rain near older trunks and leaf litter.",
    className: "seasonal",
  },
];

const navItems = [
  { id: "explore", label: "Explore", icon: Compass },
  { id: "map", label: "Map", icon: MapPin },
  { id: "capture", label: "Capture", icon: Camera, primary: true },
  { id: "cards", label: "Cards", icon: Cards },
  { id: "profile", label: "Profile", icon: UserCircle },
];

const rarityFilters = ["All", "1-2", "3-4", "5-6"];
const binderCards = [
  cardData.find((card) => card.id === "rock-pigeon"),
  cardData.find((card) => card.id === "flower"),
  cardData.find((card) => card.id === "squirrel"),
  cardData.find((card) => card.id === "butterfly"),
  cardData.find((card) => card.id === "mushroom"),
].filter(Boolean);

const captureCard = {
  ...cardData[0],
  image: "/assets/capture-blue-jay-gen.png",
  note: "Common and bold in the city. Often seen in parks and tree-lined streets.",
  serial: "#WGO-26-0704-1178",
  time: "8:47 AM",
};

const binderVisualCards = [
  {
    id: "cardinal",
    name: "Northern Cardinal",
    latin: "Cardinalis cardinalis",
    image: "/assets/binder-cardinal-gen.png",
    stars: 6,
    rarity: "City Legend",
    className: "legendary",
    confidence: 92,
    location: "Brooklyn, NY",
    date: "Jul 4, 2026",
  },
  {
    id: "squirrel-gen",
    name: "Eastern Gray Squirrel",
    latin: "Sciurus carolinensis",
    image: "/assets/binder-squirrel-gen.png",
    stars: 3,
    rarity: "Rare",
    className: "rare",
    confidence: 86,
    location: "Prospect Park",
    date: "Jul 1, 2026",
  },
  {
    id: "pigeon-gen",
    name: "Rock Pigeon",
    latin: "Columba livia",
    image: "/assets/binder-pigeon-gen.png",
    stars: 1,
    rarity: "Common",
    className: "common",
    confidence: 90,
    location: "Williamsburg",
    date: "Jun 30, 2026",
  },
  {
    id: "flower-gen",
    name: "Black-eyed Susan",
    latin: "Rudbeckia hirta",
    image: "/assets/binder-flower-gen.png",
    stars: 2,
    rarity: "Uncommon",
    className: "uncommon",
    confidence: 88,
    location: "Fort Greene Park",
    date: "Jul 2, 2026",
  },
  {
    id: "butterfly-gen",
    name: "Monarch Butterfly",
    latin: "Danaus plexippus",
    image: "/assets/binder-butterfly-gen.png",
    stars: 4,
    rarity: "Seasonal",
    className: "seasonal",
    confidence: 91,
    location: "Brooklyn Botanic Garden",
    date: "Jun 28, 2026",
  },
  {
    id: "turkey-tail-gen",
    name: "Turkey Tail",
    latin: "Trametes versicolor",
    image: "/assets/binder-turkey-tail-gen.png",
    stars: 5,
    rarity: "Local Special",
    className: "special",
    confidence: 83,
    location: "Greenpoint",
    date: "Jun 27, 2026",
  },
];

const friendActivity = [
  {
    name: "Maya",
    avatar: "/assets/friends-maya-gen.png",
    text: "unlocked a 5-Star!",
    species: "Monarch Butterfly",
    location: "Prospect Park",
    time: "2h ago",
    reward: "+50 XP",
    image: "/assets/friends-butterfly-gen.png",
  },
  {
    name: "Leo",
    avatar: "/assets/friends-leo-gen.png",
    text: "added a new card",
    species: "Honey Mushroom",
    location: "Bushwick",
    time: "3h ago",
    reward: "+20 XP",
    image: "/assets/friends-mushroom-gen.png",
  },
];

function Stars({ count, compact = false }) {
  return (
    <div className={`stars ${compact ? "compact" : ""}`} aria-label={`${count} star rarity`}>
      {Array.from({ length: 6 }).map((_, index) => (
        <Star
          key={index}
          size={compact ? 12 : 18}
          weight={index < count ? "fill" : "regular"}
        />
      ))}
    </div>
  );
}

function CaptureHeroCard({ card, flipped, motionEnabled, onFlip }) {
  return (
    <Tilt
      className="capture-card-shell"
      tiltEnable={!flipped}
      tiltReverse
      tiltMaxAngleX={11}
      tiltMaxAngleY={13}
      perspective={820}
      scale={1.01}
      transitionSpeed={220}
      gyroscope={motionEnabled}
      glareEnable
      glareMaxOpacity={0.12}
      glareColor="#ffffff"
      glarePosition="all"
      glareBorderRadius="1.45rem"
    >
      <button
        type="button"
        className={`capture-card ${flipped ? "is-flipped" : ""}`}
        onClick={onFlip}
        aria-label={`${card.name}, new six star holo card`}
      >
        <span className="capture-card-inner">
          <span className="capture-face capture-front">
            <span className="capture-rarity">CITY LEGEND</span>
            <span className="capture-top-stars"><Stars count={6} /></span>
            <span className="capture-photo">
              <img src={card.image} alt="" />
              <span className="capture-location">
                <MapPin size={15} weight="regular" />
                Approx location
                <Info size={14} weight="bold" />
              </span>
            </span>
            <span className="capture-info">
              <span className="capture-copy">
                <strong>{card.name}</strong>
                <em>{card.latin}</em>
                <span>{card.note}</span>
              </span>
              <span className="capture-confidence">
                <small>Likely match</small>
                <b>{card.confidence}%</b>
                <i aria-hidden="true"><span style={{ width: `${card.confidence}%` }} /></i>
                <small>AI confidence</small>
              </span>
            </span>
            <span className="capture-foot">
              <span>
                <Leaf size={18} weight="bold" />
                <small>First seen</small>
                Jul 4, 2026 · {card.time}
              </span>
              <b>{card.serial}</b>
            </span>
            <FoilOverlay finish="oil-slick" intensity={1.28} tilt={false} specular shimmer />
            <span className="capture-holo" />
          </span>
          <span className="capture-face capture-back">
            <strong>{card.name}</strong>
            <em>{card.latin}</em>
            <p>{card.note}</p>
          </span>
        </span>
      </button>
    </Tilt>
  );
}

function BinderCard({ card, variant = "small" }) {
  const isLegend = card.stars >= 6;
  const finish = card.stars >= 6 ? "oil-slick" : card.stars >= 5 ? "foil" : card.stars === 4 ? "galaxy" : "etched";
  const intensity = card.stars >= 6 ? 1.12 : card.stars >= 5 ? 0.72 : card.stars === 4 ? 0.48 : card.stars === 3 ? 0.28 : 0;

  return (
    <Tilt
      className={`binder-card-shell ${variant} ${card.className}`}
      tiltEnable={variant !== "tiny"}
      tiltReverse
      tiltMaxAngleX={variant === "feature" ? 7 : 4}
      tiltMaxAngleY={variant === "feature" ? 9 : 5}
      perspective={900}
      scale={1}
      glareEnable={isLegend}
      glareMaxOpacity={0.1}
      glareBorderRadius={variant === "feature" ? "1rem" : "0.72rem"}
    >
      <article className={`binder-card ${variant} ${card.className}`}>
        <span className="binder-card-top">
          <span className="binder-star-badge">
            {variant === "feature" ? (
              <>
                <strong>{card.stars}</strong>
                <small>STARS</small>
              </>
            ) : (
              <Stars count={card.stars} compact />
            )}
          </span>
          {variant === "feature" && <Stars count={6} />}
          <span className="binder-kind"><Leaf size={18} weight="fill" /></span>
        </span>
        <span className="binder-photo">
          <img src={card.image} alt="" />
          {variant === "feature" && <span className="tilt-chip"><Swap size={15} />TILT TO SHIMMER</span>}
        </span>
        <span className="binder-card-copy">
          <strong>{card.name}</strong>
          <em>{card.latin}</em>
        </span>
        <span className="binder-card-meta">
          <span>
            <small>APP RARITY</small>
            {card.rarity}
          </span>
          <span>
            <small>AI CONFIDENCE</small>
            {card.confidence}%
            <i aria-hidden="true" />
          </span>
        </span>
        {variant === "feature" && (
          <span className="binder-feature-foot">
            <span><LockKey size={15} weight="fill" /> Location softened</span>
            <span>{card.location}<br />{card.date}</span>
          </span>
        )}
        {intensity > 0 && <FoilOverlay finish={finish} intensity={intensity} tilt={false} specular shimmer={isLegend} />}
      </article>
    </Tilt>
  );
}

function ShowcaseCard({ card, className = "" }) {
  const finish = card.stars >= 6 ? "oil-slick" : card.stars >= 3 ? "etched" : "foil";
  return (
    <Tilt
      className={`showcase-card-shell ${className} ${card.className}`}
      tiltEnable
      tiltReverse
      tiltMaxAngleX={5}
      tiltMaxAngleY={7}
      perspective={900}
      glareEnable={card.stars >= 6}
      glareMaxOpacity={0.1}
      glareBorderRadius="1.1rem"
    >
      <article className={`showcase-card ${card.className}`}>
        <span className="showcase-stars">{card.stars}<Star size={18} weight="fill" /></span>
        <span className="showcase-rarity">{card.stars >= 6 ? "URBAN LEGEND" : card.rarity.toUpperCase()}</span>
        <img src={card.image} alt="" />
        <span className="showcase-copy">
          <strong>{card.name}</strong>
          <em>{card.latin}</em>
          <Stars count={Math.min(card.stars, 6)} />
        </span>
        {card.stars >= 6 && <span className="round-stamp">MY PHOTO<br />BROOKLYN, NY</span>}
        {card.stars >= 3 && <FoilOverlay finish={finish} intensity={card.stars >= 6 ? 1 : 0.35} tilt={false} specular shimmer={card.stars >= 6} />}
      </article>
    </Tilt>
  );
}

function CreatureCard({
  card,
  size = "medium",
  interactive = false,
  flipped = false,
  motionEnabled = false,
  onFlip,
  onSelect,
}) {
  const [pressed, setPressed] = useState(false);
  const isHero = size === "hero";
  const isMini = size === "mini";
  const isStack = size.includes("stack");
  const canTilt = interactive || isStack || size === "large";
  const foilFinish = card.stars >= 6 ? "oil-slick" : card.stars === 5 ? "foil" : card.stars === 4 ? "galaxy" : "etched";
  const foilIntensity = card.stars >= 6 ? 1.06 : card.stars === 5 ? 0.86 : card.stars === 4 ? 0.66 : card.stars === 3 ? 0.38 : 0;

  function resetPress() {
    setPressed(false);
  }

  return (
    <Tilt
      className={`card-tilt-shell ${size} ${card.className} ${canTilt ? "tilt-enabled" : ""}`}
      tiltEnable={canTilt && !flipped}
      tiltReverse
      tiltMaxAngleX={isHero ? 12 : 6}
      tiltMaxAngleY={isHero ? 14 : 7}
      perspective={isHero ? 820 : 980}
      scale={interactive ? 1.015 : 1}
      transitionSpeed={220}
      gyroscope={interactive && motionEnabled}
      glareEnable={interactive}
      glareMaxOpacity={0.14}
      glareColor="#ffffff"
      glarePosition="all"
      glareBorderRadius={isHero ? "1.28rem" : "1rem"}
    >
      <button
        type="button"
        className={`creature-card ${size} ${card.className} ${interactive ? "interactive" : ""} ${
          flipped ? "is-flipped" : ""
        } ${pressed ? "is-pressed" : ""}`}
        onPointerDown={() => interactive && setPressed(true)}
        onPointerUp={() => setPressed(false)}
        onPointerCancel={resetPress}
        onPointerLeave={resetPress}
        onClick={onSelect}
        aria-label={`${card.name}, ${card.stars} star ${card.rarity} card`}
      >
        <span className="card-inner">
          <span className="card-face card-front">
            <span className="rarity-corner">
              <strong>{card.stars}</strong>
              {isHero && <small>stars</small>}
              {!isHero && <Star size={isMini ? 10 : 14} weight="fill" />}
            </span>
            {isHero && (
              <>
                <span className="hero-star-strip">
                  <Stars count={card.stars} />
                </span>
                <span className="photo-stamp">
                  <Camera size={20} weight="fill" />
                  <small>My photo</small>
                </span>
                <span className="location-pill">
                  <MapPin size={14} weight="fill" />
                  {card.privacy}
                  <Info size={13} weight="bold" />
                </span>
              </>
            )}
            <span className="card-finish">
              {isHero ? card.rarity.toUpperCase() : card.rarity}
              {isHero && <PawPrint size={18} weight="fill" />}
            </span>
            <span className="photo-frame">
              <img src={card.image} alt="" />
            </span>
            <span className="card-copy">
              <span>
                <strong>{card.name}</strong>
                <em>{card.latin}</em>
              </span>
              <Stars count={card.stars} compact={!isHero} />
            </span>
            {isHero && (
              <span className="hero-bottom-stars">
                <Stars count={card.stars} />
              </span>
            )}
            {!isMini && (
              <span className="card-meta">
                <span>
                  <small>Rarity</small>
                  {card.rarity}
                </span>
                <span>
                  <small>AI match</small>
                  <b>{card.confidence}%</b>
                  {isHero && (
                    <i style={{ "--confidence": `${card.confidence}%` }} aria-hidden="true" />
                  )}
                </span>
                {isHero && (
                  <span>
                    <small>First seen</small>
                    {card.date}
                  </span>
                )}
              </span>
            )}
            {isHero && (
              <span className="privacy-strip">
                <LockKey size={15} weight="fill" />
                Location softened to protect wildlife
              </span>
            )}
            {foilIntensity > 0 && (
              <FoilOverlay
                finish={foilFinish}
                intensity={foilIntensity}
                tilt={false}
                specular
                shimmer={card.stars >= 5}
              />
            )}
            {card.stars === 6 && <span className="holo-sheen" />}
          </span>
          <span className="card-face card-back">
            <span className="back-mark">WG</span>
            <strong>{card.name}</strong>
            <em>{card.latin}</em>
            <p>{card.note}</p>
            <span className="back-row">
              <MapPin size={15} weight="fill" />
              {card.privacy}
            </span>
            <span className="back-row">
              <Sparkle size={15} weight="fill" />
              Rarity is discovery difficulty
            </span>
          </span>
        </span>
        {interactive && (
          <span className="card-hitbar">
            <span>Move phone or finger to catch foil</span>
            <span>{pressed ? "Pressed depth" : "Library tilt active"}</span>
          </span>
        )}
        {onFlip && (
          <span
            className="flip-hotspot"
            onClick={(event) => {
              event.stopPropagation();
              onFlip();
            }}
          >
            Flip
          </span>
        )}
      </button>
    </Tilt>
  );
}

function TopBar({ activeView }) {
  const titles = {
    capture: "New card unlocked",
    cards: "My Binder",
    map: "Soft Map",
    explore: "Today nearby",
    profile: "City Explorer",
  };
  const title = titles[activeView] ?? "Wild Go";

  return (
    <header className={`topbar topbar-${activeView}`}>
      <div className="brand-lockup">
        <p className="brand">Wild Go</p>
        <h1>{title}</h1>
      </div>
      <span className="top-divider" />
      <div className="progress-cluster" aria-label="NYC collection progress">
        <span>NYC Collection <CaretDown size={13} weight="fill" /></span>
        <strong>243 / 500 species</strong>
        <div className="progress-track">
          <span style={{ width: "49%" }} />
        </div>
      </div>
      <div className="level-badge">
        <small>Lv.</small>
        23
      </div>
      <button className="bell-button" type="button" aria-label="Notifications">
        <Bell size={27} />
        <span />
      </button>
    </header>
  );
}

function CaptureView({ selected, setSelected }) {
  const [flipped, setFlipped] = useState(false);
  const [saved, setSaved] = useState(false);
  const [motionEnabled, setMotionEnabled] = useState(false);
  const featured = captureCard;

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
    <section className="view capture-view">
      <header className="capture-top">
        <button type="button" aria-label="Back"><ArrowLeft size={23} weight="bold" /></button>
        <span><Leaf size={31} weight="bold" />Wild Go</span>
        <button type="button" aria-label="Binder"><BookOpen size={24} weight="bold" /></button>
      </header>

      <div className="unlock-head">
        <span aria-hidden="true" />
        <h1>New card unlocked</h1>
        <p>Move phone to catch the foil</p>
      </div>

      <CaptureHeroCard
        card={featured}
        flipped={flipped}
        motionEnabled={motionEnabled}
        onFlip={() => setFlipped((value) => !value)}
      />

      <div className="gesture-row" aria-label="Card physical interactions">
        <button type="button" onClick={enableMotion} className={motionEnabled ? "is-on" : ""}>
          <Swap size={22} />
          <strong>Tilt</strong>
          <span>{motionEnabled ? "Live motion" : "Catch foil"}</span>
        </button>
        <button type="button">
          <HandTap size={22} />
          <strong>Press & Hold</strong>
          <span>Feel depth</span>
        </button>
        <button type="button" onClick={() => setFlipped((value) => !value)}>
          <Cards size={22} />
          <strong>Flip</strong>
          <span>View details</span>
        </button>
      </div>

      <div className="capture-dots" aria-label="Card tips">
        <span className="active" />
        <span />
        <span />
        <span />
      </div>

      <div className="action-row">
        <button className="primary-action" type="button" onClick={() => setSaved(true)}>
          <Cards size={22} weight="fill" />
          {saved ? "Added to Binder" : "Add to Binder"}
        </button>
        <button className="secondary-action" type="button">
          <ShareFat size={21} />
          Share Card
        </button>
      </div>
    </section>
  );
}

function CardsView({ selected, setSelected, setActiveView }) {
  const [filter, setFilter] = useState("All");
  const cards = useMemo(() => {
    if (filter === "All") return cardData;
    const [min, max] = filter.split("-").map(Number);
    return cardData.filter((card) => card.stars >= min && card.stars <= max);
  }, [filter]);

  return (
    <section className="view cards-view">
      <header className="binder-head">
        <div>
          <p className="brand">Wild Go</p>
        </div>
        <div className="binder-progress">
          <span>NYC Collection <CaretDown size={13} weight="fill" /></span>
          <i><b style={{ width: "49%" }} /></i>
          <small>243 / 500 species</small>
        </div>
        <div className="level-badge">
          <small>Lv.</small>
          23
        </div>
        <button className="bell-button" type="button" aria-label="Notifications">
          <Bell size={26} />
          <span />
        </button>
      </header>

      <div className="binder-tabs" aria-label="Binder sections">
        <button type="button" className="active"><BookOpen size={23} />My Binder</button>
        <button type="button"><Stack size={23} />Stacks</button>
        <button type="button"><Flag size={23} />Missions</button>
        <button type="button" onClick={() => setActiveView("friends")}><Users size={23} />Friends</button>
      </div>

      <div className="binder-toolbar">
        <button type="button">Recent <CaretDown size={16} weight="bold" /></button>
        <strong>134 Cards</strong>
        <span>
          <button type="button" className="active"><GridFour size={20} weight="fill" /></button>
          <button type="button"><ListBullets size={21} /></button>
        </span>
      </div>

      <div className="binder-board">
        <span className="binder-ring ring-a" />
        <span className="binder-ring ring-b" />
        <BinderCard card={binderVisualCards[0]} variant="feature" />
        <BinderCard card={binderVisualCards[1]} variant="tall" />
        <div className="binder-minis">
          {binderVisualCards.slice(2).map((card) => (
            <BinderCard key={card.id} card={card} variant="tiny" />
          ))}
        </div>
      </div>

      <div className="rarity-guide binder-rarity">
        <small>RARITY GUIDE</small>
        <div className="rarity-scale">
          {[
            ["★", "1", "Common", "Matte"],
            ["★★", "2", "Uncommon", "Colored"],
            ["★★★", "3", "Rare", "Metallic"],
            ["★★★★", "4", "Seasonal", "Iridescent"],
            ["★★★★★", "5", "Local Special", "Foil"],
            ["★★★★★★", "6", "City Legend", "Holo Foil"],
          ].map(([stars, number, label, finish]) => (
            <span key={number}>
              <b>{stars}</b>
              <strong>{number}</strong>
              <small>{label}</small>
              <em>{finish}</em>
            </span>
          ))}
        </div>
      </div>

      <p className="binder-tip"><Swap size={27} /> Tilt your phone slowly to see the holo cards shimmer. <button type="button"><Info size={18} /> Binder Tips</button></p>
    </section>
  );
}

function FriendsPreview() {
  const [showcased, setShowcased] = useState(false);

  return (
    <section className="friends-preview">
      <div className="view-title">
        <div>
          <h2>Friends' Finds</h2>
          <p>Maya unlocked a 5-star Monarch Butterfly</p>
          <small>Prospect Park · 2h ago</small>
        </div>
        <button type="button">See all</button>
      </div>

      <div className={`social-stack ${showcased ? "is-showcased" : ""}`}>
        <button
          type="button"
          className="stack-drop-zone"
          aria-pressed={showcased}
          onClick={() => setShowcased((value) => !value)}
        >
          <HandTap size={17} weight="fill" />
          <span>{showcased ? "Showcase live" : "Drop to showcase"}</span>
        </button>
        <CreatureCard card={cardData[3]} size="stack back" />
        <CreatureCard card={cardData[2]} size="stack mid" />
        <CreatureCard card={cardData[4]} size="stack front" />
      </div>

      <div className="share-tray">
        <button type="button">
          <ShareFat size={20} />
          Share
        </button>
        <button type="button" onClick={() => setShowcased((value) => !value)}>
          <Star size={20} weight="fill" />
          {showcased ? "Showcased" : "Showcase"}
        </button>
      </div>

    </section>
  );
}

function FriendsView() {
  const [showcased, setShowcased] = useState(false);
  const legendCard = {
    ...binderVisualCards[0],
    image: "/assets/friends-cardinal-gen.png",
    rarity: "Six Star",
  };

  return (
    <section className="view friends-view">
      <header className="friends-head">
        <p className="brand">Wild Go</p>
        <h1>Friends' Finds</h1>
        <button className="bell-button" type="button" aria-label="Notifications">
          <Bell size={26} />
          <span />
        </button>
      </header>

      <div className="friends-stats">
        <img src="/assets/friends-leo-gen.png" alt="" />
        <div>
          <strong>Level 24 · City Explorer</strong>
          <i><b style={{ width: "76%" }} /></i>
          <span>2,340 <em>/ 3,000 XP</em></span>
        </div>
        <span><Cards size={28} /> <b>248</b><small>Cards</small></span>
        <span><MapPin size={28} /> <b>34</b><small>Places</small></span>
      </div>

      <div className={`friends-showcase ${showcased ? "is-showcased" : ""}`}>
        <ShowcaseCard card={{ ...binderVisualCards[2], name: "Oxeye Daisy", latin: "Leucanthemum vulgare", image: "/assets/binder-flower-gen.png" }} className="back" />
        <ShowcaseCard card={binderVisualCards[1]} className="mid" />
        <ShowcaseCard card={legendCard} className="front" />
      </div>

      <div className="friends-drop-row">
        <button
          type="button"
          className="friends-drop-zone"
          aria-pressed={showcased}
          onClick={() => setShowcased((value) => !value)}
        >
          <HandTap size={24} />
          Drag to showcase
        </button>
        <button type="button" className="friends-flip"><Cards size={24} />Flip</button>
      </div>

      <section className="friend-activity">
        <div className="friend-activity-title">
          <h2>Friend Activity</h2>
          <button type="button">See all</button>
        </div>
        {friendActivity.map((item) => (
          <article key={item.name} className="friend-row">
            <img className="friend-avatar" src={item.avatar} alt="" />
            <div>
              <strong>{item.name} {item.text}</strong>
              <span>{item.species}</span>
              <small>{item.location} · {item.time}</small>
            </div>
            <img className="friend-thumb" src={item.image} alt="" />
            <em>{item.reward}</em>
          </article>
        ))}
      </section>

      <div className="friends-action-rail">
        <button type="button"><PaperPlaneTilt size={26} />Send Card</button>
        <button type="button"><Cards size={26} />Compare</button>
        <button type="button" className="camera"><Camera size={36} weight="fill" /></button>
        <button type="button"><Star size={28} />Add to Showcase</button>
        <button type="button"><Handshake size={28} />Trade Later</button>
      </div>
    </section>
  );
}

function ExploreView() {
  return (
    <section className="view explore-view">
      <div className="view-title">
        <div>
          <h2>Today nearby</h2>
          <p>Short quests for real walks, commutes, and parks.</p>
        </div>
        <Binoculars size={28} weight="duotone" />
      </div>
      <div className="mission-panel">
        {[
          ["Morning Flyers", "Capture one bird before 10 AM", "2 / 3"],
          ["Yellow Bloom", "Find one yellow flower", "1 / 1"],
          ["Soft Map", "Record from 2 different approximate areas", "1 / 2"],
        ].map(([title, body, progress]) => (
          <button type="button" className="mission-row" key={title}>
            <span>
              <strong>{title}</strong>
              <small>{body}</small>
            </span>
            <em>{progress}</em>
          </button>
        ))}
      </div>
      <div className="map-panel">
        <span className="pin pin-a" />
        <span className="pin pin-b" />
        <span className="pin pin-c" />
        <strong>Brooklyn nature map</strong>
        <p>Sensitive cards show approximate areas by default.</p>
      </div>
    </section>
  );
}

function MapView() {
  return (
    <section className="view explore-view">
      <div className="view-title">
        <div>
          <h2>Soft Map</h2>
          <p>Approximate neighborhoods by default, never exact rare-card pins.</p>
        </div>
        <MapPin size={28} weight="duotone" />
      </div>
      <div className="map-panel">
        <span className="pin pin-a" />
        <span className="pin pin-b" />
        <span className="pin pin-c" />
        <strong>Brooklyn nature map</strong>
        <p>Sensitive finds are softened to a wider area before sharing.</p>
      </div>
    </section>
  );
}

function ProfileView() {
  return (
    <section className="view profile-view">
      <div className="profile-card">
        <div className="profile-avatar">J</div>
        <h2>City Explorer</h2>
        <p>Level 24 · 2,340 / 3,000 XP</p>
        <div className="profile-stats">
          <span>
            <strong>248</strong>
            Cards
          </span>
          <span>
            <strong>34</strong>
            Places
          </span>
          <span>
            <strong>6</strong>
            Holo
          </span>
        </div>
      </div>
      <div className="safety-card">
        <strong>Wildlife-safe by default</strong>
        <p>No exact public locations for rare or sensitive finds. Observe from a distance.</p>
      </div>
    </section>
  );
}

export function App() {
  const [activeView, setActiveView] = useState(() => {
    const view = window.location.hash.replace("#", "");
    return ["capture", "cards", "friends", "map", "explore", "profile"].includes(view) ? view : "capture";
  });
  const [selected, setSelected] = useState(cardData[0]);
  const showGlobalTopbar = !["capture", "cards", "friends"].includes(activeView);
  const showBottomNav = activeView !== "capture";

  function changeView(id) {
    setActiveView(id);
    window.history.replaceState(null, "", `#${id}`);
  }

  return (
    <main className="app-shell">
      <div className={`phone-surface is-${activeView}`}>
        {showGlobalTopbar && <TopBar activeView={activeView} />}

        {activeView === "capture" && <CaptureView selected={selected} setSelected={setSelected} />}
        {activeView === "cards" && <CardsView selected={selected} setSelected={setSelected} setActiveView={changeView} />}
        {activeView === "friends" && <FriendsView />}
        {activeView === "map" && <MapView />}
        {activeView === "explore" && <ExploreView />}
        {activeView === "profile" && <ProfileView />}

        {showBottomNav && <nav className="bottom-nav" aria-label="Primary">
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                type="button"
                className={`${activeView === item.id ? "active" : ""} ${
                  item.primary ? "capture-button" : ""
                }`}
                onClick={() => changeView(item.id)}
              >
                <span>
                  <Icon size={item.primary ? 28 : 22} weight={activeView === item.id ? "fill" : "regular"} />
                </span>
                {item.label}
              </button>
            );
          })}
        </nav>}
      </div>
    </main>
  );
}
