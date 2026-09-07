/**
 * Run inside the target Figma file:
 * Plugins → Development → Import plugin from manifest…
 * Select this folder's manifest.json, then run the plugin.
 * Creates cards 5–10 next to any existing cards on the current page.
 */

function solid(c, a) {
  return [{ type: "SOLID", color: c, opacity: a == null ? 1 : a }];
}

async function loadFonts() {
  const styles = ["Regular", "Medium", "SemiBold", "Bold"];
  for (const style of styles) {
    await figma.loadFontAsync({ family: "Noto Sans Arabic", style });
  }
  await figma.loadFontAsync({ family: "Inter", style: "Regular" });
  await figma.loadFontAsync({ family: "Inter", style: "Medium" });
  await figma.loadFontAsync({ family: "Inter", style: "Semi Bold" });
  await figma.loadFontAsync({ family: "Inter", style: "Bold" });
}

function txt(chars, size, style, color, opts) {
  opts = opts || {};
  const t = figma.createText();
  t.fontName = {
    family: opts.latin ? "Inter" : "Noto Sans Arabic",
    style: opts.latin && style === "SemiBold" ? "Semi Bold" : style,
  };
  t.characters = chars;
  t.fontSize = size;
  t.fills = solid(color);
  if (opts.align) t.textAlignHorizontal = opts.align;
  if (opts.w) {
    t.textAutoResize = "HEIGHT";
    t.resize(opts.w, size * 1.4);
  }
  return t;
}

function auto(dir, gap, pad, fill) {
  const f = figma.createFrame();
  f.layoutMode = dir;
  f.primaryAxisSizingMode = "AUTO";
  f.counterAxisSizingMode = "FIXED";
  f.itemSpacing = gap;
  if (typeof pad === "number") {
    f.paddingTop = f.paddingBottom = f.paddingLeft = f.paddingRight = pad;
  } else if (pad) {
    f.paddingTop = pad.t || 0;
    f.paddingBottom = pad.b || 0;
    f.paddingLeft = pad.l || 0;
    f.paddingRight = pad.r || 0;
  }
  f.fills = fill ? solid(fill) : [];
  f.clipsContent = false;
  return f;
}

function rightmostX(page) {
  let max = 0;
  for (const n of page.children) {
    if ("width" in n) max = Math.max(max, n.x + n.width);
  }
  return max + 40;
}

function brandFooter(width, dark) {
  const ink = dark
    ? { r: 0.85, g: 0.85, b: 0.88 }
    : { r: 0.2, g: 0.16, b: 0.14 };
  const muted = dark
    ? { r: 0.6, g: 0.6, b: 0.65 }
    : { r: 0.45, g: 0.4, b: 0.36 };
  const foot = auto("VERTICAL", 4, { t: 12, b: 0, l: 0, r: 0 });
  foot.counterAxisAlignItems = "CENTER";
  foot.counterAxisSizingMode = "FIXED";
  foot.resize(width, 10);
  const line = figma.createRectangle();
  line.resize(width, 1);
  line.fills = solid(dark ? { r: 0.3, g: 0.3, b: 0.35 } : { r: 0.88, g: 0.84, b: 0.78 });
  foot.appendChild(line);
  foot.appendChild(txt("دکتر دارایی", 14, "Bold", ink, { align: "CENTER" }));
  foot.appendChild(
    txt("سمینار مدیریت مالی و سرمایه‌گذاری", 11, "Regular", muted, {
      align: "CENTER",
    })
  );
  return foot;
}

function circleChoice(label, accent) {
  const row = auto("HORIZONTAL", 8, { t: 10, b: 10, l: 12, r: 12 }, {
    r: 1,
    g: 1,
    b: 1,
  });
  row.cornerRadius = 12;
  row.strokes = solid({ r: 0.88, g: 0.86, b: 0.84 });
  row.strokeWeight = 1;
  row.counterAxisAlignItems = "CENTER";
  row.primaryAxisAlignItems = "CENTER";
  const c = figma.createEllipse();
  c.resize(18, 18);
  c.fills = [];
  c.strokes = solid(accent);
  c.strokeWeight = 2;
  row.appendChild(c);
  row.appendChild(txt(label, 14, "Medium", { r: 0.18, g: 0.14, b: 0.12 }));
  return row;
}

function makeCard5(x, y) {
  const cream = { r: 0.98, g: 0.95, b: 0.9 };
  const ink = { r: 0.18, g: 0.14, b: 0.12 };
  const muted = { r: 0.45, g: 0.38, b: 0.32 };
  const purple = { r: 0.42, g: 0.28, b: 0.55 };
  const teal = { r: 0.15, g: 0.45, b: 0.48 };
  const soft = { r: 0.94, g: 0.9, b: 0.84 };

  const card = auto("VERTICAL", 14, 24, cream);
  card.name = "05 — روانشناسی سرمایه‌گذاری";
  card.resize(450, 920);
  card.primaryAxisSizingMode = "FIXED";
  card.counterAxisSizingMode = "FIXED";
  card.cornerRadius = 28;
  card.x = x;
  card.y = y;

  const head = auto("VERTICAL", 8, 0);
  head.counterAxisAlignItems = "CENTER";
  head.counterAxisSizingMode = "FIXED";
  head.resize(402, 10);
  const icon = auto("HORIZONTAL", 0, 0, purple);
  icon.resize(64, 64);
  icon.cornerRadius = 32;
  icon.primaryAxisAlignItems = "CENTER";
  icon.counterAxisAlignItems = "CENTER";
  icon.primaryAxisSizingMode = "FIXED";
  icon.counterAxisSizingMode = "FIXED";
  icon.appendChild(txt("🧠", 26, "Regular", { r: 1, g: 1, b: 1 }, { latin: true }));
  head.appendChild(icon);
  head.appendChild(txt("روانشناسی سرمایه‌گذاری", 24, "Bold", ink, { align: "CENTER" }));
  head.appendChild(
    txt("سرمایه‌گذار چه نوعی هستی؟", 13, "Regular", muted, { align: "CENTER" })
  );
  card.appendChild(head);
  head.layoutSizingHorizontal = "FILL";

  const scenarios = [
    {
      q: "همه اطرافیانت در حال خرید یک دارایی‌اند. تو؟",
      opts: ["خریدم", "صبر کردم", "تحقیق کردم", "فروختم"],
    },
    {
      q: "سرمایه‌ات ۲۰٪ کاهش پیدا کرده. واکنشت؟",
      opts: ["فروختم", "بیشتر خریدم", "صبر کردم", "پانیک کردم"],
    },
    {
      q: "یک فرصت با ریسک بالا. تصمیم؟",
      opts: ["وارد شدم", "رد کردم", "نصفه رفتم", "مشورت گرفتم"],
    },
  ];

  for (const s of scenarios) {
    const block = auto("VERTICAL", 8, 14, { r: 1, g: 1, b: 1 });
    block.cornerRadius = 14;
    block.strokes = solid({ r: 0.88, g: 0.82, b: 0.74 });
    block.strokeWeight = 1;
    block.counterAxisSizingMode = "FIXED";
    block.resize(402, 10);
    block.appendChild(txt(s.q, 13, "SemiBold", ink, { w: 374, align: "RIGHT" }));
    for (const o of s.opts) {
      const chip = circleChoice(o, purple);
      block.appendChild(chip);
      chip.layoutSizingHorizontal = "FILL";
    }
    card.appendChild(block);
    block.layoutSizingHorizontal = "FILL";
  }

  const result = auto("VERTICAL", 10, 14, soft);
  result.cornerRadius = 14;
  result.counterAxisSizingMode = "FIXED";
  result.resize(402, 10);
  result.appendChild(
    txt("نوع سرمایه‌گذار تو (دایره بکش):", 12, "SemiBold", ink, {
      align: "RIGHT",
      w: 370,
    })
  );
  const badges = auto("HORIZONTAL", 8, 0);
  badges.layoutWrap = "WRAP";
  badges.counterAxisSizingMode = "AUTO";
  badges.primaryAxisSizingMode = "AUTO";
  for (const tp of ["ترسو", "طمع‌کار", "FOMO-زده", "عاقلانه"]) {
    const b = circleChoice(tp, teal);
    b.cornerRadius = 20;
    badges.appendChild(b);
  }
  result.appendChild(badges);
  card.appendChild(result);
  result.layoutSizingHorizontal = "FILL";

  card.appendChild(
    txt("مجری درباره FOMO، ترس و طمع توضیح می‌دهد", 12, "Regular", muted, {
      align: "CENTER",
      w: 402,
    })
  );
  const foot = brandFooter(402, false);
  card.appendChild(foot);
  foot.layoutSizingHorizontal = "FILL";
  return card;
}

function makeCard6(x, y) {
  const bg = { r: 0.06, g: 0.06, b: 0.07 };
  const red = { r: 0.86, g: 0.18, b: 0.18 };
  const white = { r: 1, g: 1, b: 1 };
  const muted = { r: 0.7, g: 0.7, b: 0.72 };

  const card = auto("VERTICAL", 16, 24, bg);
  card.name = "06 — تصمیم در ۳۰ ثانیه";
  card.resize(450, 800);
  card.primaryAxisSizingMode = "FIXED";
  card.counterAxisSizingMode = "FIXED";
  card.cornerRadius = 28;
  card.x = x;
  card.y = y;

  const head = auto("VERTICAL", 6, 0);
  head.counterAxisAlignItems = "CENTER";
  head.counterAxisSizingMode = "FIXED";
  head.resize(402, 10);
  head.appendChild(txt("⏱", 36, "Regular", red, { latin: true, align: "CENTER" }));
  head.appendChild(txt("۳۰ ثانیه", 42, "Bold", white, { align: "CENTER" }));
  head.appendChild(
    txt("تصمیم در ۳۰ ثانیه", 18, "SemiBold", red, { align: "CENTER" })
  );
  card.appendChild(head);
  head.layoutSizingHorizontal = "FILL";

  const scenario = auto("VERTICAL", 8, 16, { r: 0.12, g: 0.12, b: 0.14 });
  scenario.cornerRadius = 16;
  scenario.strokes = solid(red, 0.7);
  scenario.dashPattern = [6, 4];
  scenario.strokeWeight = 2;
  scenario.counterAxisSizingMode = "FIXED";
  scenario.resize(402, 10);
  scenario.appendChild(
    txt("سناریو (توسط مجری خوانده می‌شود)", 11, "Medium", muted, {
      align: "CENTER",
      w: 370,
    })
  );
  scenario.appendChild(
    txt(
      "سرمایه‌ات در حال کاهش است و اطلاعات ضدونقیض داری...",
      14,
      "Regular",
      white,
      { align: "CENTER", w: 370 }
    )
  );
  card.appendChild(scenario);
  scenario.layoutSizingHorizontal = "FILL";

  const actions = [
    { l: "فروختم", c: { r: 0.86, g: 0.18, b: 0.18 } },
    { l: "نگه داشتم", c: { r: 0.2, g: 0.7, b: 0.35 } },
    { l: "تنوع دادم", c: { r: 0.25, g: 0.45, b: 0.9 } },
    { l: "نقد موندم", c: { r: 0.75, g: 0.75, b: 0.78 } },
  ];
  for (const a of actions) {
    const row = auto("HORIZONTAL", 10, { t: 14, b: 14, l: 16, r: 16 }, {
      r: 0.14,
      g: 0.14,
      b: 0.16,
    });
    row.cornerRadius = 12;
    row.strokes = solid(a.c);
    row.strokeWeight = 2;
    row.counterAxisAlignItems = "CENTER";
    row.primaryAxisAlignItems = "CENTER";
    const c = figma.createEllipse();
    c.resize(20, 20);
    c.fills = [];
    c.strokes = solid(a.c);
    c.strokeWeight = 2;
    row.appendChild(c);
    row.appendChild(txt(a.l, 16, "Bold", white));
    card.appendChild(row);
    row.layoutSizingHorizontal = "FILL";
  }

  const conf = auto("VERTICAL", 8, 12, { r: 0.12, g: 0.12, b: 0.14 });
  conf.cornerRadius = 12;
  conf.counterAxisAlignItems = "CENTER";
  conf.counterAxisSizingMode = "FIXED";
  conf.resize(402, 10);
  conf.appendChild(txt("چقدر مطمئن بودی؟", 13, "Medium", muted, { align: "CENTER" }));
  const stars = auto("HORIZONTAL", 8, 0);
  stars.primaryAxisAlignItems = "CENTER";
  for (let i = 1; i <= 5; i++) {
    const s = auto("HORIZONTAL", 0, 8, { r: 0.2, g: 0.2, b: 0.22 });
    s.cornerRadius = 8;
    s.primaryAxisAlignItems = "CENTER";
    s.counterAxisAlignItems = "CENTER";
    s.appendChild(txt(String(i), 14, "Bold", white, { latin: true }));
    stars.appendChild(s);
  }
  conf.appendChild(stars);
  card.appendChild(conf);
  conf.layoutSizingHorizontal = "FILL";

  card.appendChild(
    txt("تصمیم جمع روی صفحه نمایش داده می‌شود", 12, "Regular", muted, {
      align: "CENTER",
      w: 402,
    })
  );
  const foot = brandFooter(402, true);
  card.appendChild(foot);
  foot.layoutSizingHorizontal = "FILL";
  return card;
}

function makeCard7(x, y) {
  const navy = { r: 0.06, g: 0.1, b: 0.22 };
  const gold = { r: 0.9, g: 0.72, b: 0.28 };
  const white = { r: 1, g: 1, b: 1 };
  const muted = { r: 0.7, g: 0.75, b: 0.85 };

  const card = auto("VERTICAL", 14, 24, navy);
  card.name = "07 — پیش‌بینی تا ۱۴۰۸";
  card.resize(450, 820);
  card.primaryAxisSizingMode = "FIXED";
  card.counterAxisSizingMode = "FIXED";
  card.cornerRadius = 28;
  card.x = x;
  card.y = y;

  const head = auto("VERTICAL", 6, 0);
  head.counterAxisAlignItems = "CENTER";
  head.counterAxisSizingMode = "FIXED";
  head.resize(402, 10);
  head.appendChild(txt("✦", 28, "Regular", gold, { latin: true, align: "CENTER" }));
  head.appendChild(txt("پیش‌بینی تا ۱۴۰۸", 24, "Bold", gold, { align: "CENTER" }));
  head.appendChild(
    txt("سال ۱۴۰۸ — افق بازار از دید تو", 13, "Regular", muted, {
      align: "CENTER",
    })
  );
  card.appendChild(head);
  head.layoutSizingHorizontal = "FILL";

  const assets = ["طلا", "ارز", "بورس", "کریپتو", "مسکن"];
  for (const a of assets) {
    const row = auto("VERTICAL", 8, 12, { r: 0.1, g: 0.14, b: 0.28 });
    row.cornerRadius = 12;
    row.counterAxisSizingMode = "FIXED";
    row.resize(402, 10);
    const top = auto("HORIZONTAL", 10, 0);
    top.counterAxisAlignItems = "CENTER";
    top.primaryAxisAlignItems = "SPACE_BETWEEN";
    top.counterAxisSizingMode = "FIXED";
    top.resize(378, 10);
    top.appendChild(txt(a, 15, "Bold", white));
    const trends = auto("HORIZONTAL", 6, 0);
    for (const t of ["⬆️ رشد", "⬇️ افت", "➡️ ثابت"]) {
      const chip = auto("HORIZONTAL", 0, { t: 6, b: 6, l: 8, r: 8 }, {
        r: 0.14,
        g: 0.18,
        b: 0.34,
      });
      chip.cornerRadius = 8;
      chip.strokes = solid(gold, 0.5);
      chip.strokeWeight = 1;
      chip.appendChild(txt(t, 11, "Medium", gold));
      trends.appendChild(chip);
    }
    top.appendChild(trends);
    row.appendChild(top);
    top.layoutSizingHorizontal = "FILL";

    const field = auto("HORIZONTAL", 0, { t: 10, b: 10, l: 12, r: 12 }, {
      r: 0.08,
      g: 0.11,
      b: 0.22,
    });
    field.cornerRadius = 8;
    field.strokes = solid(gold, 0.35);
    field.dashPattern = [4, 4];
    field.strokeWeight = 1;
    field.counterAxisSizingMode = "FIXED";
    field.resize(378, 10);
    field.appendChild(
      txt("پیش‌بینی دقیق‌تر تو: ....................", 12, "Regular", muted, {
        align: "RIGHT",
        w: 350,
      })
    );
    row.appendChild(field);
    field.layoutSizingHorizontal = "FILL";
    card.appendChild(row);
    row.layoutSizingHorizontal = "FILL";
  }

  const conf = auto("VERTICAL", 8, 12, { r: 0.1, g: 0.14, b: 0.28 });
  conf.cornerRadius = 12;
  conf.counterAxisAlignItems = "CENTER";
  conf.counterAxisSizingMode = "FIXED";
  conf.resize(402, 10);
  conf.appendChild(
    txt("چقدر به پیش‌بینی خودت اطمینان داری؟ ۱ تا ۱۰", 12, "Medium", muted, {
      align: "CENTER",
      w: 370,
    })
  );
  const scale = auto("HORIZONTAL", 4, 0);
  for (let i = 1; i <= 10; i++) {
    const n = auto("HORIZONTAL", 0, 6, { r: 0.14, g: 0.18, b: 0.34 });
    n.cornerRadius = 6;
    n.primaryAxisAlignItems = "CENTER";
    n.appendChild(txt(String(i), 11, "Bold", gold, { latin: true }));
    scale.appendChild(n);
  }
  conf.appendChild(scale);
  card.appendChild(conf);
  conf.layoutSizingHorizontal = "FILL";

  card.appendChild(
    txt("پیش‌بینی‌های جمع روی صفحه بزرگ نمایش داده می‌شود", 11, "Regular", muted, {
      align: "CENTER",
      w: 402,
    })
  );
  const foot = brandFooter(402, true);
  card.appendChild(foot);
  foot.layoutSizingHorizontal = "FILL";
  return card;
}

function makeCard8(x, y) {
  const beige = { r: 0.96, g: 0.94, b: 0.88 };
  const green = { r: 0.18, g: 0.42, b: 0.32 };
  const ink = { r: 0.16, g: 0.18, b: 0.14 };
  const muted = { r: 0.42, g: 0.4, b: 0.34 };

  const card = auto("VERTICAL", 14, 24, beige);
  card.name = "08 — اگر جای من بودی؟";
  card.resize(450, 860);
  card.primaryAxisSizingMode = "FIXED";
  card.counterAxisSizingMode = "FIXED";
  card.cornerRadius = 28;
  card.x = x;
  card.y = y;

  const head = auto("VERTICAL", 8, 0);
  head.counterAxisAlignItems = "CENTER";
  head.counterAxisSizingMode = "FIXED";
  head.resize(402, 10);
  head.appendChild(txt("🤔", 32, "Regular", green, { latin: true, align: "CENTER" }));
  head.appendChild(
    txt("اگر جای من بودی چه کار می‌کردی؟", 20, "Bold", ink, {
      align: "CENTER",
      w: 380,
    })
  );
  card.appendChild(head);
  head.layoutSizingHorizontal = "FILL";

  const scen = auto("VERTICAL", 8, 16, { r: 1, g: 1, b: 1 });
  scen.cornerRadius = 14;
  scen.strokes = solid(green);
  scen.strokeWeight = 1.5;
  scen.counterAxisSizingMode = "FIXED";
  scen.resize(402, 10);
  scen.appendChild(
    txt(
      "۲ میلیارد تومان سرمایه داری، ۳۰ ساله هستی و می‌خواهی در ۵ سال آینده خانه بخری. چه کار می‌کنی؟",
      14,
      "Medium",
      ink,
      { align: "RIGHT", w: 370 }
    )
  );
  card.appendChild(scen);
  scen.layoutSizingHorizontal = "FILL";

  const opts = [
    "A — همه را در بورس می‌گذارم",
    "B — بخشی طلا، بخشی سپرده",
    "C — ملک می‌خرم همین الان",
    "D — ترکیب متنوع — بنویس: _______",
  ];
  for (const o of opts) {
    const row = circleChoice(o, green);
    card.appendChild(row);
    row.layoutSizingHorizontal = "FILL";
  }

  const reason = auto("VERTICAL", 6, 12, { r: 1, g: 1, b: 1 });
  reason.cornerRadius = 12;
  reason.strokes = solid({ r: 0.85, g: 0.82, b: 0.74 });
  reason.dashPattern = [5, 4];
  reason.strokeWeight = 1;
  reason.counterAxisSizingMode = "FIXED";
  reason.resize(402, 10);
  reason.appendChild(
    txt("دلیل اصلی انتخابم: _______________________________", 13, "Regular", muted, {
      align: "RIGHT",
      w: 370,
    })
  );
  card.appendChild(reason);
  reason.layoutSizingHorizontal = "FILL";

  const reveal = auto("VERTICAL", 8, 12, { r: 0.92, g: 0.95, b: 0.9 });
  reveal.cornerRadius = 12;
  reveal.counterAxisSizingMode = "FIXED";
  reveal.resize(402, 10);
  reveal.appendChild(txt("اعلان زنده مجری:", 12, "SemiBold", green, { align: "RIGHT", w: 370 }));
  for (const r of ["✅ بهترین تصمیم: _______", "❌ بدترین تصمیم: _______", "💡 نظر کارشناس: _______"]) {
    reveal.appendChild(txt(r, 13, "Regular", ink, { align: "RIGHT", w: 370 }));
  }
  card.appendChild(reveal);
  reveal.layoutSizingHorizontal = "FILL";

  const foot = brandFooter(402, false);
  card.appendChild(foot);
  foot.layoutSizingHorizontal = "FILL";
  return card;
}

function makeCrisisCard(type, x, y) {
  const map = {
    crisis: {
      name: "09A — کارت بحران",
      bg: { r: 0.72, g: 0.12, b: 0.12 },
      title: "کارت بحران",
      icon: "🔥",
      body: "هزینه‌های شما ۳۰٪ افزایش یافت",
      prompt: "کجا هزینه کاهش می‌دهید؟ بنویس:",
      ink: { r: 1, g: 1, b: 1 },
    },
    opportunity: {
      name: "09B — کارت فرصت",
      bg: { r: 0.12, g: 0.48, b: 0.28 },
      title: "کارت فرصت",
      icon: "🚀",
      body: "یک دارایی با قیمت مناسب پیدا شد",
      prompt: "وارد می‌شوی؟ چرا؟ بنویس:",
      ink: { r: 0.05, g: 0.1, b: 0.08 },
    },
    intel: {
      name: "09C — کارت اطلاعات",
      bg: { r: 0.12, g: 0.28, b: 0.58 },
      title: "کارت اطلاعات",
      icon: "📡",
      body: "خبر جدید منتشر شده — واقعی یا شایعه؟",
      prompt: "تصمیمت را بنویس + دلیل:",
      ink: { r: 1, g: 1, b: 1 },
    },
  };
  const m = map[type];
  const card = auto("VERTICAL", 12, 18, m.bg);
  card.name = m.name;
  card.resize(252, 352);
  card.primaryAxisSizingMode = "FIXED";
  card.counterAxisSizingMode = "FIXED";
  card.cornerRadius = 16;
  card.x = x;
  card.y = y;
  card.primaryAxisAlignItems = "CENTER";
  card.counterAxisAlignItems = "CENTER";

  card.appendChild(txt(m.icon, 36, "Regular", m.ink, { latin: true, align: "CENTER" }));
  card.appendChild(txt(m.title, 20, "Bold", m.ink, { align: "CENTER" }));
  card.appendChild(txt(m.body, 13, "Medium", m.ink, { align: "CENTER", w: 210 }));

  const write = auto("VERTICAL", 6, 10, { r: 1, g: 1, b: 1, });
  write.fills = solid({ r: 1, g: 1, b: 1 }, 0.18);
  write.cornerRadius = 10;
  write.counterAxisSizingMode = "FIXED";
  write.resize(216, 90);
  write.appendChild(txt(m.prompt, 11, "SemiBold", m.ink, { align: "RIGHT", w: 196 }));
  write.appendChild(
    txt("................................\n................................\n................................", 12, "Regular", m.ink, {
      align: "RIGHT",
      w: 196,
    })
  );
  card.appendChild(write);

  card.appendChild(
    txt("تصمیم خودت رو نگه دار — مجری تحلیل می‌کند", 9, "Regular", m.ink, {
      align: "CENTER",
      w: 216,
    })
  );
  card.appendChild(txt("دکتر دارایی", 10, "Bold", m.ink, { align: "CENTER" }));
  return card;
}

function makeCard10(x, y) {
  const bg = { r: 0.08, g: 0.1, b: 0.1 };
  const gold = { r: 0.86, g: 0.7, b: 0.28 };
  const white = { r: 1, g: 1, b: 1 };
  const muted = { r: 0.65, g: 0.68, b: 0.62 };
  const panel = { r: 0.12, g: 0.15, b: 0.14 };

  const card = auto("VERTICAL", 12, 20, bg);
  card.name = "10 — بازی بزرگ ۷۲ ساعت بحران";
  card.resize(1123, 794);
  card.primaryAxisSizingMode = "FIXED";
  card.counterAxisSizingMode = "FIXED";
  card.cornerRadius = 20;
  card.x = x;
  card.y = y;

  const head = auto("HORIZONTAL", 16, 0);
  head.counterAxisAlignItems = "CENTER";
  head.primaryAxisAlignItems = "SPACE_BETWEEN";
  head.counterAxisSizingMode = "FIXED";
  head.resize(1083, 10);
  const titleCol = auto("VERTICAL", 4, 0);
  titleCol.appendChild(txt("بازی بزرگ ۷۲ ساعت بحران", 28, "Bold", gold));
  titleCol.appendChild(
    txt("هر ۲۰ دقیقه سمینار = یک روز بحران", 13, "Regular", muted)
  );
  head.appendChild(titleCol);
  const meta = auto("VERTICAL", 6, 12, panel);
  meta.cornerRadius = 10;
  meta.appendChild(txt("نام تیم: _______________", 13, "Medium", white));
  meta.appendChild(txt("سرمایه اولیه: ۱ میلیارد تومان", 13, "Bold", gold));
  head.appendChild(meta);
  card.appendChild(head);
  head.layoutSizingHorizontal = "FILL";

  const body = auto("HORIZONTAL", 16, 0);
  body.counterAxisSizingMode = "FIXED";
  body.resize(1083, 560);
  body.primaryAxisSizingMode = "FIXED";

  const grid = auto("VERTICAL", 10, 0);
  grid.counterAxisSizingMode = "FIXED";
  grid.resize(720, 10);
  grid.appendChild(txt("ردیف‌های بحران", 14, "SemiBold", gold, { align: "RIGHT", w: 700 }));

  for (let day = 1; day <= 3; day++) {
    const row = auto("VERTICAL", 8, 12, panel);
    row.cornerRadius = 12;
    row.counterAxisSizingMode = "FIXED";
    row.resize(720, 10);
    row.appendChild(txt("روز " + day + " — رویداد: _______________________________", 14, "Bold", white, { align: "RIGHT", w: 690 }));
    const decisions = auto("HORIZONTAL", 8, 0);
    for (const d of ["نگه داشتم", "فروختم", "تنوع دادم", "نقد موندم"]) {
      const chip = circleChoice(d, gold);
      chip.fills = solid({ r: 0.16, g: 0.2, b: 0.18 });
      chip.strokes = solid(gold, 0.6);
      decisions.appendChild(chip);
    }
    row.appendChild(decisions);
    row.appendChild(
      txt("توضیح: _______________________________________________", 12, "Regular", muted, {
        align: "RIGHT",
        w: 690,
      })
    );
    const score = auto("HORIZONTAL", 6, 0);
    score.counterAxisAlignItems = "CENTER";
    score.appendChild(txt("امتیاز پایداری:", 12, "Medium", muted));
    for (let i = 1; i <= 10; i++) {
      const n = auto("HORIZONTAL", 0, 4, { r: 0.18, g: 0.22, b: 0.2 });
      n.cornerRadius = 4;
      n.appendChild(txt(String(i), 10, "Bold", gold, { latin: true }));
      score.appendChild(n);
    }
    row.appendChild(score);
    grid.appendChild(row);
    row.layoutSizingHorizontal = "FILL";
  }
  body.appendChild(grid);

  const side = auto("VERTICAL", 10, 14, panel);
  side.cornerRadius = 12;
  side.counterAxisSizingMode = "FIXED";
  side.primaryAxisSizingMode = "FIXED";
  side.resize(340, 560);
  side.appendChild(txt("ردیاب دارایی‌ها (%)", 14, "SemiBold", gold, { align: "RIGHT", w: 310 }));
  const header = auto("HORIZONTAL", 4, 0);
  header.appendChild(txt("دارایی", 11, "Bold", muted, { w: 70, align: "RIGHT" }));
  for (const h of ["د۱", "د۲", "د۳"]) {
    header.appendChild(txt(h, 11, "Bold", muted, { latin: true, w: 50, align: "CENTER" }));
  }
  side.appendChild(header);
  for (const a of ["طلا", "بورس", "ارز", "کریپتو", "ملک", "نقد"]) {
    const r = auto("HORIZONTAL", 4, { t: 8, b: 8, l: 0, r: 0 });
    r.counterAxisAlignItems = "CENTER";
    r.appendChild(txt(a, 12, "Medium", white, { w: 70, align: "RIGHT" }));
    for (let i = 0; i < 3; i++) {
      const cell = auto("HORIZONTAL", 0, 6, { r: 0.1, g: 0.13, b: 0.12 });
      cell.cornerRadius = 6;
      cell.strokes = solid(gold, 0.35);
      cell.dashPattern = [3, 3];
      cell.strokeWeight = 1;
      cell.resize(50, 28);
      cell.primaryAxisSizingMode = "FIXED";
      cell.counterAxisSizingMode = "FIXED";
      cell.primaryAxisAlignItems = "CENTER";
      cell.counterAxisAlignItems = "CENTER";
      cell.appendChild(txt("%", 11, "Regular", muted, { latin: true }));
      r.appendChild(cell);
    }
    side.appendChild(r);
  }
  body.appendChild(side);
  card.appendChild(body);
  body.layoutSizingHorizontal = "FILL";

  const finals = auto("HORIZONTAL", 12, 0);
  finals.primaryAxisAlignItems = "SPACE_BETWEEN";
  finals.counterAxisSizingMode = "FIXED";
  finals.resize(1083, 10);
  for (const f of ["بیشترین پایداری 🛡️", "بهترین تصمیم 🧠", "برنده نهایی 🏆"]) {
    const box = auto("VERTICAL", 6, 12, panel);
    box.cornerRadius = 10;
    box.counterAxisAlignItems = "CENTER";
    box.resize(340, 10);
    box.counterAxisSizingMode = "FIXED";
    box.appendChild(txt(f, 14, "Bold", gold, { align: "CENTER" }));
    box.appendChild(txt("_______________", 13, "Regular", muted, { align: "CENTER" }));
    finals.appendChild(box);
  }
  card.appendChild(finals);
  finals.layoutSizingHorizontal = "FILL";

  const foot = brandFooter(1083, true);
  card.appendChild(foot);
  foot.layoutSizingHorizontal = "FILL";
  return card;
}

async function main() {
  await loadFonts();
  const page = figma.currentPage;
  page.name = "Game Cards — Dr. Daraei";

  let x = rightmostX(page);
  const y = 0;
  const created = [];

  const c5 = makeCard5(x, y);
  page.appendChild(c5);
  created.push(c5.id);
  x += 450 + 40;

  const c6 = makeCard6(x, y);
  page.appendChild(c6);
  created.push(c6.id);
  x += 450 + 40;

  const c7 = makeCard7(x, y);
  page.appendChild(c7);
  created.push(c7.id);
  x += 450 + 40;

  const c8 = makeCard8(x, y);
  page.appendChild(c8);
  created.push(c8.id);
  x += 450 + 40;

  const c9a = makeCrisisCard("crisis", x, y);
  page.appendChild(c9a);
  created.push(c9a.id);
  const c9b = makeCrisisCard("opportunity", x + 272, y);
  page.appendChild(c9b);
  created.push(c9b.id);
  const c9c = makeCrisisCard("intel", x + 544, y);
  page.appendChild(c9c);
  created.push(c9c.id);
  x += 544 + 252 + 40;

  const c10 = makeCard10(x, y);
  page.appendChild(c10);
  created.push(c10.id);

  figma.viewport.scrollAndZoomIntoView([c5, c6, c7, c8, c9a, c9b, c9c, c10]);
  figma.closePlugin("کارت‌های ۵ تا ۱۰ ساخته شد (" + created.length + " فریم)");
}

main().catch((e) => {
  figma.closePlugin("Error: " + String(e));
});
