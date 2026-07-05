import { useMemo, useState } from "react";
import Tilt from "react-parallax-tilt";
import { FoilOverlay } from "card-foil/react";
import "card-foil/style.css";
import {
  Binoculars,
  Bell,
  Camera,
  Cards,
  CaretDown,
  Compass,
  FunnelSimple,
  HandTap,
  Info,
  Leaf,
  LockKey,
  MapPin,
  PawPrint,
  ShareFat,
  Sparkle,
  Stack,
  Star,
  Swap,
  UserCircle,
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
  const featured = selected ?? cardData[0];

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
      <div className="stage-copy">
        <span className="stage-kicker">
          <Sparkle size={16} weight="fill" />
          Six-star holo foil
        </span>
        <p>Likely match {featured.confidence}% · {featured.privacy}</p>
      </div>

      <CreatureCard
        card={featured}
        size="hero"
        interactive
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
          <strong>Press</strong>
          <span>Feel depth</span>
        </button>
        <button type="button" onClick={() => setFlipped((value) => !value)}>
          <Cards size={22} />
          <strong>Flip</strong>
          <span>View details</span>
        </button>
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

      <div className="quick-binder">
        <div className="section-heading">
          <span>Your Binder</span>
          <small>134 cards</small>
          <button type="button">See all</button>
        </div>
        <div className="mini-card-row">
          {binderCards.map((card) => (
            <CreatureCard
              key={card.id}
              card={card}
              size="mini"
              onSelect={() => {
                setSelected(card);
                setFlipped(false);
              }}
            />
          ))}
        </div>
      </div>

      <FriendsPreview />

      <div className="wildlife-note">
        <Leaf size={19} weight="bold" />
        <span>Rarity is discovery difficulty, not conservation status.</span>
        <span>Wildlife first. Observe from a distance.</span>
      </div>
    </section>
  );
}

function CardsView({ selected, setSelected }) {
  const [filter, setFilter] = useState("All");
  const cards = useMemo(() => {
    if (filter === "All") return cardData;
    const [min, max] = filter.split("-").map(Number);
    return cardData.filter((card) => card.stars >= min && card.stars <= max);
  }, [filter]);

  return (
    <section className="view cards-view">
      <div className="view-title">
        <div>
          <h2>My Binder</h2>
          <p>134 cards · 34 places · 6 star ceiling</p>
        </div>
        <button type="button" className="icon-button">
          <FunnelSimple size={19} />
        </button>
      </div>

      <div className="filter-row" aria-label="Rarity filters">
        {rarityFilters.map((item) => (
          <button
            key={item}
            type="button"
            className={filter === item ? "selected" : ""}
            onClick={() => setFilter(item)}
          >
            {item}
          </button>
        ))}
      </div>

      <div className="binder-grid">
        {cards.map((card) => (
          <CreatureCard
            key={card.id}
            card={card}
            size={card.id === selected?.id ? "large" : "medium"}
            onSelect={() => setSelected(card)}
          />
        ))}
      </div>

      <div className="rarity-guide">
        <div className="section-heading">
          <span>Rarity guide</span>
          <Info size={16} />
        </div>
        <div className="rarity-scale">
          {[
            ["1", "Common", "Matte"],
            ["2", "Uncommon", "Color"],
            ["3", "Rare", "Metal"],
            ["4", "Seasonal", "Iridescent"],
            ["5", "Local", "Foil"],
            ["6", "Legend", "Holo foil"],
          ].map(([stars, label, finish]) => (
            <span key={stars}>
              <strong>{stars}</strong>
              <small>{label}</small>
              <em>{finish}</em>
            </span>
          ))}
        </div>
        <p>Rarity is discovery difficulty, not conservation status.</p>
      </div>
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
  return (
    <section className="view friends-view">
      <FriendsPreview />
      <div className="activity-list">
        {[
          ["Maya", "unlocked a 5-star Monarch Butterfly", cardData[4], "+50 XP"],
          ["Leo", "added a new Honey Mushroom card", cardData[5], "+20 XP"],
          ["Joey", "completed Morning Flyers 3/3", cardData[0], "+1 badge"],
        ].map(([name, text, card, reward]) => (
          <article key={name} className="activity-item">
            <div className="avatar">{name.slice(0, 1)}</div>
            <div>
              <strong>{name}</strong>
              <span>{text}</span>
              <small>{card.location} · {card.privacy}</small>
            </div>
            <img src={card.image} alt="" />
            <em>{reward}</em>
          </article>
        ))}
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
  const [activeView, setActiveView] = useState("capture");
  const [selected, setSelected] = useState(cardData[0]);

  return (
    <main className="app-shell">
      <div className="phone-surface">
        <TopBar activeView={activeView} />

        {activeView === "capture" && <CaptureView selected={selected} setSelected={setSelected} />}
        {activeView === "cards" && <CardsView selected={selected} setSelected={setSelected} />}
        {activeView === "friends" && <FriendsView />}
        {activeView === "map" && <MapView />}
        {activeView === "explore" && <ExploreView />}
        {activeView === "profile" && <ProfileView />}

        <nav className="bottom-nav" aria-label="Primary">
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                type="button"
                className={`${activeView === item.id ? "active" : ""} ${
                  item.primary ? "capture-button" : ""
                }`}
                onClick={() => setActiveView(item.id)}
              >
                <span>
                  <Icon size={item.primary ? 28 : 22} weight={activeView === item.id ? "fill" : "regular"} />
                </span>
                {item.label}
              </button>
            );
          })}
        </nav>
      </div>
    </main>
  );
}
