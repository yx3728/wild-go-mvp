import { useMemo, useState } from "react";
import {
  Binoculars,
  Camera,
  Cards,
  Compass,
  FunnelSimple,
  HandTap,
  HouseLine,
  Info,
  MapPin,
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
    date: "Today, 8:47 AM",
    privacy: "Approx location",
    note: "Bold, noisy, and usually spotted near mature street trees.",
    className: "legendary",
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
  { id: "friends", label: "Friends", icon: Stack },
  { id: "capture", label: "Capture", icon: Camera, primary: true },
  { id: "cards", label: "Cards", icon: Cards },
  { id: "profile", label: "Profile", icon: UserCircle },
];

const rarityFilters = ["All", "1-2", "3-4", "5-6"];

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
  onFlip,
  onSelect,
}) {
  const [tilt, setTilt] = useState({ x: 0, y: 0, shineX: 50, shineY: 50 });
  const [pressed, setPressed] = useState(false);

  function handlePointerMove(event) {
    if (!interactive) return;
    const rect = event.currentTarget.getBoundingClientRect();
    const px = (event.clientX - rect.left) / rect.width;
    const py = (event.clientY - rect.top) / rect.height;
    setTilt({
      x: (py - 0.5) * -14,
      y: (px - 0.5) * 18,
      shineX: px * 100,
      shineY: py * 100,
    });
  }

  function resetTilt() {
    setTilt({ x: 0, y: 0, shineX: 50, shineY: 50 });
    setPressed(false);
  }

  const style = interactive
    ? {
        "--tilt-x": `${tilt.x}deg`,
        "--tilt-y": `${tilt.y}deg`,
        "--shine-x": `${tilt.shineX}%`,
        "--shine-y": `${tilt.shineY}%`,
      }
    : undefined;

  return (
    <button
      type="button"
      className={`creature-card ${size} ${card.className} ${interactive ? "interactive" : ""} ${
        flipped ? "is-flipped" : ""
      } ${pressed ? "is-pressed" : ""}`}
      style={style}
      onPointerMove={handlePointerMove}
      onPointerDown={() => interactive && setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={resetTilt}
      onClick={onSelect}
      aria-label={`${card.name}, ${card.stars} star ${card.rarity} card`}
    >
      <span className="card-inner">
        <span className="card-face card-front">
          <span className="rarity-corner">
            <strong>{card.stars}</strong>
            <Star size={size === "mini" ? 10 : 14} weight="fill" />
          </span>
          <span className="card-finish">{card.rarity}</span>
          <span className="photo-frame">
            <img src={card.image} alt="" />
          </span>
          <span className="card-copy">
            <span>
              <strong>{card.name}</strong>
              <em>{card.latin}</em>
            </span>
            <Stars count={card.stars} compact={size !== "hero"} />
          </span>
          {size !== "mini" && (
            <span className="card-meta">
              <span>
                <small>Rarity</small>
                {card.rarity}
              </span>
              <span>
                <small>AI match</small>
                {card.confidence}%
              </span>
            </span>
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
          <span>Move phone to catch foil</span>
          <span>{pressed ? "Pressed depth" : "Tilt enabled"}</span>
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
  );
}

function TopBar({ activeView }) {
  const titles = {
    capture: "New card unlocked",
    cards: "My Binder",
    friends: "Friends' Finds",
    explore: "Today nearby",
    profile: "City Explorer",
  };
  const title = titles[activeView] ?? "Wild Go";

  return (
    <header className="topbar">
      <div>
        <p className="brand">Wild Go</p>
        <h1>{title}</h1>
      </div>
      <div className="progress-cluster" aria-label="NYC collection progress">
        <span>NYC</span>
        <strong>243 / 500</strong>
        <div className="progress-track">
          <span style={{ width: "49%" }} />
        </div>
      </div>
      <div className="level-badge">
        <small>Lv.</small>
        24
      </div>
    </header>
  );
}

function CaptureView({ selected, setSelected }) {
  const [flipped, setFlipped] = useState(false);
  const [saved, setSaved] = useState(false);
  const featured = selected ?? cardData[0];

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
        onFlip={() => setFlipped((value) => !value)}
      />

      <div className="gesture-row" aria-label="Card physical interactions">
        <button type="button">
          <Swap size={22} />
          <strong>Tilt</strong>
          <span>Catch foil</span>
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
          <span>Binder preview</span>
          <button type="button">See all</button>
        </div>
        <div className="mini-card-row">
          {cardData.slice(1).map((card) => (
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

function FriendsView() {
  const [showcased, setShowcased] = useState(false);

  return (
    <section className="view friends-view">
      <div className="view-title">
        <div>
          <h2>Friends' Finds</h2>
          <p>Collection milestones from your city circle.</p>
        </div>
        <span className="stat-pill">+70 XP</span>
      </div>

      <div className={`social-stack ${showcased ? "is-showcased" : ""}`}>
        <CreatureCard card={cardData[2]} size="stack back" />
        <CreatureCard card={cardData[1]} size="stack mid" />
        <CreatureCard card={cardData[0]} size="stack front" />
      </div>

      <div className="share-tray">
        <button type="button">
          <ShareFat size={20} />
          Send Card
        </button>
        <button type="button">
          <Swap size={20} />
          Compare
        </button>
        <button type="button" onClick={() => setShowcased((value) => !value)}>
          <Star size={20} weight="fill" />
          {showcased ? "Showcased" : "Showcase"}
        </button>
      </div>

      <div className="activity-list">
        {[
          ["Maya", "unlocked a 5-star Monarch Butterfly", cardData[3], "+50 XP"],
          ["Leo", "added a new Honey Mushroom card", cardData[4], "+20 XP"],
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
