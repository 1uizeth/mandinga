# Mandinga Protocol

### *A Permissionless Savings Primitive for Everyone*

*Lightpaper v0.3 — March 2026*

*Savings circles are one of the oldest and most widely used financial tools in the world. Communities across every continent independently invented the same primitive: pool contributions from a group of savers, rotate the full amount to one member per round, repeat until everyone has received the pool once. No interest. No credit bureau. No institution in the middle. Just collective savings turned into individual access to meaningful capital (the equipment to start a business, the vehicle to expand one, the home to build a life in) sooner than any of the members could reach it alone.*

*The mechanism is sound. Its only structural failure is the organiser: the person who holds the pot, decides the rotation order, and is trusted not to disappear. When that trust breaks, the circle breaks. Every attempt to fix this has introduced institutions (banks, cooperatives, regulators) that recreate the very gatekeeping the circle was built to avoid.*

*Mandinga Protocol is the savings circle without the organiser. A permissionless, self-custodial primitive that runs the rotation on-chain, enforces contributions through code, and is governed by the members who participate in it. No single point of failure. No auction that lets capital purchase earlier access. No administration fee paid regardless of when you are served. The ancient mechanism, finally structurally sound: a savings primitive that belongs to the people who use it.*

## 1. The Problem

### 1.1 Acquiring Productive Assets Requires Credit — or Years of Waiting

Most people save toward something specific. A vehicle that expands what they can earn. Equipment that makes a business possible. A home. An asset that is productive, durable, and beyond what can be purchased from a month's savings.

There are two paths to assets of this scale. The first is credit: borrow the amount now, pay it back over time. The second is linear saving: set aside a portion of income each period until the total accumulates.

Credit works. It delivers the asset when it can generate value. But credit runs through institutions (banks, cooperatives, microfinance lenders) that gate access through identity verification, credit history, collateral, and geography. For a large portion of the world's population, one or more of these requirements is a barrier. Not because they are incapable of repaying. Because the institution has no way of knowing that, or no commercial incentive to find out.

Linear saving is the alternative available to everyone. But it is slow by design. The asset that could expand your income next year requires years of accumulation to reach. And during those years of saving, you are not yet benefiting from what you are saving toward.

The savings circle was invented to solve exactly this problem: collectively, without an institution, and without requiring anyone to prove anything to anyone outside the group.

### 1.2 The World Invented the Answer Thousands of Years Ago

Communities across every continent independently invented the same solution: the rotating savings and credit association. It goes by many names: consórcio in Brazil, chama in East Africa, tanda in Mexico, hui in China, paluwagan in the Philippines, equb in Ethiopia, susu in West Africa, stokvel in South Africa, gye in Korea. The same primitive, invented everywhere humans organised themselves economically.

The mechanic is simple. A group of people contribute a fixed amount regularly. The pooled total rotates to one member per round. Everyone eventually receives the same lump sum. The member who receives it first gets the advantage of deploying a larger amount earlier. The member who receives it last has effectively saved patiently while others benefited.

What makes this work is not charity. It is collective accountability: horizontal, mutual, between equals. The group is the mechanism. The community IS the collateral. No bank. No credit bureau. No identity verification.

According to the World Bank, roughly 25% of adults in sub-Saharan Africa report having used a savings circle. Estimates suggest hundreds of millions of people globally participate in some form of rotating savings. This is not a niche instrument. It is the dominant savings technology for much of humanity.

### 1.3 The Structural Failure Mode

ROSCAs and savings circles have one catastrophic vulnerability: the organiser. In every traditional implementation, one person holds the pot, decides the rotation order, and is trusted by all members not to abscond. When that person disappears, or when an early-payout member stops contributing after receiving the lump sum, the circle collapses. Members waiting for later payouts lose everything they contributed.

This is not a rare edge case. It is the reason ROSCAs remain informal, local, and trust-constrained. You can only participate with people you know personally, in close geographic proximity, with strong social accountability. The social trust that makes them work is also the ceiling that prevents them from scaling.

Every attempt to formalise ROSCAs has tried to solve this with reputation systems, identity verification, or legal enforcement. Each solution imports the exact surveillance and gatekeeping apparatus that makes traditional finance inaccessible to the very people who need savings circles in the first place.

### 1.4 Case Study: What Happened to the Consórcio in Brazil

Brazil offers the clearest and most instructive example of what happens when a savings primitive is institutionalised and what it can become when it succeeds. The consórcio, the Brazilian expression of the rotating savings circle, has existed since the 1960s, is regulated by the Banco Central do Brasil, and today reaches over 10 million active participants. By 2025, the sector processed more than $100 billion in credit volume, representing over 6% of Brazilian GDP. Understanding what it became, and how, is not simply a cautionary tale. It is a reflection on a success story that drifted, and what that drift reveals about the primitive underneath.

#### The Original Promise: Better Than Financing

The consórcio began as a genuinely attractive alternative to traditional bank lending. In a country where the Selic rate currently sits at 15% per year and mortgage financing rates run 11--12% annually on top of inflation correction, the consórcio offered something structurally different: no interest, only a fixed administration fee unaffected by Selic movements. For a R\$200,000 real estate credit, the total administration fee runs 15--20% of the credit value spread across the contract, dramatically cheaper than compound interest over the same period, where the equivalent financing could cost 60--100% more in total outlay.

With ticket sizes routinely in the hundreds of thousands of reais across real estate and vehicle segments, and central bank oversight lending it legal legitimacy, the consórcio became something informal ROSCAs could never be: a regulated financial instrument that competes directly with bank lending. Brazil took a tool of social survival (the circle communities built to function without access to banks) and turned it into an instrument of high finance.

This advantage is real. From January to April 2025 alone, new consórcio enrolments grew 19.1% year-on-year, with the real estate segment up 41%. The market expects to surpass 11 million active participants in 2026 with 25% segment growth. But cheaper than financing in Brazil is a low bar. And the comparison conceals a misalignment that is foundational: the administration fee is paid in full regardless of when you are contemplated. Contemplated in month two or month 118 of a 120-month plan, you pay the same total fee. The fee structure rewards the administradora identically whether it serves you early or late.

#### The Auction Mechanic: A Sophistication That Left Ordinary Members Behind

The original ROSCA logic distributes lump-sum access through rotation: every member receives the pool once, timing determined by lot or agreed sequence. The consórcio preserved this through its monthly sorteio (lottery draw). The sorteio is the cooperative spirit in its purest form: you win by luck, not by wealth. Every member has an equal chance at early access regardless of capital.

But the consórcio added a second contemplation path: the lance, a competitive bid auction held alongside each monthly assembly. Any member can offer a lance, a percentage of the credit value, to win early contemplation over the sorteio. The highest bidder wins.

The lance is, in its own way, a genuine financial innovation, and precisely the feature that explains how the consórcio scaled to 6% of Brazilian GDP. It allows urgent capital needs to be met without waiting on luck. It turns the group mechanism into something that competes with credit markets on their own terms. Informal ROSCAs cannot do this. The Banco Central can regulate this. The lance is the sophistication that made the consórcio a serious financial instrument.

It is also the feature that broke the cooperative logic. The structural benefit that gave ROSCAs their purpose, giving everyone equal access to lump-sum capital in turn, became purchasable by those who already had capital. The wealthiest participant in the circle gets the money first. Every month. Indefinitely. The sorteio remains. But for anyone who can afford to bid, it is merely a fallback.

The lance embutido added further complexity. This mechanism lets members bid using part of their own carta de crédito as the offer: a member with a R\$100,000 carta can offer a 30% embedded lance of R\$30,000 to accelerate contemplation, receiving only R\$70,000 when contemplated. The intent was to democratise auction access for members without large capital reserves. The effect was a new layer of opaque calculation: participants must weigh reducing their effective credit against accelerating contemplation, based on group dynamics they cannot fully observe. The instrument grew more sophisticated. The ordinary saver fell further behind.

#### The Secondary Market: From Savings to Speculation

Once institutionalised, the consórcio developed a secondary market for cotas (quota positions) that transformed the product entirely. A contemplated cota commands a premium called ágio. In practice, the ágio on a recently contemplated quota runs 25--35% of the credit value in early group months, declining as the group matures. A R\$200,000 carta contemplada might be sold on the secondary market for R\$40,000--R\$70,000 in entry premium, with the buyer assuming remaining installment obligations.

This spawned an entire class of consórcio strategists: consultants selling strategies for leveraging net worth through coordinated quota acquisition, contemplation timing, and secondary market arbitrage. These strategies are rational for those who know them. They are completely invisible to ordinary participants, and they extract from the group pool in ways that ordinary members neither understand nor consent to.

By 2025, the consórcio system issued over 5.16 million new quotas in a single year. It is no longer a community savings tool. It is an institutionalised credit market using rotating pool mechanics as its legal structure, with secondary markets, strategic arbitrage, and information asymmetries that systematically favour sophisticated actors over ordinary ones.

> [!IMPORTANT]
> **The Institutional Capture Pattern**
>
> *The consórcio is not a failure. It is a drift. What began as a savings primitive (no interest, equal access, community-governed) became the most significant credit instrument in Brazil, regulated by the Banco Central and processing over $100 billion a year. That is a genuine achievement. But the carta de crédito is not your savings returned. It is credit extended against future obligations. The lance is not democratised access. It is the auction of the one thing ROSCAs were built to distribute equally. The community lost ownership of the mechanism. The institution gained it. This is the pattern Mandinga Protocol is built not to repeat.*

### 1.5 Brazil as the Experimentation Layer

Brazil offers something unique for what comes next: a population of 200 million people who have already demonstrated they will adopt new financial technology at scale, if it genuinely serves them.

PIX, Brazil's instant payment system, launched in November 2020 and reached 100 million users within two years. By 2023, it processed more transactions than credit and debit cards combined, became the dominant payment method for the informal economy, and was adopted voluntarily by people who had never had a bank account. No payment system in history reached this scale this fast.

PIX is significant not because it is technologically remarkable. It is a government-operated clearing layer, not a blockchain. It is significant because it demonstrates that Brazil is not a late adopter of financial technology. It is a first adopter when the technology actually reduces friction for the people it claims to serve.

The consórcio, with its 10 million active participants and centuries of cultural precedent, is the other half of this picture. Brazil already has a population that understands rotating savings. They know what a circle is. They have experienced both what works (the rotation mechanic, the absence of interest, the cooperative logic) and what was captured (the lance that made timing purchasable by capital, the administradora's opacity, the ágio premium that systematically enriches sophisticated actors at ordinary members' expense).

Brazil is the right place to prove that a savings circle can be made trustless and genuinely fair. Not because it lacks financial infrastructure. Because it has the cultural vocabulary, the scale, and the demonstrated willingness to adopt financial technology that actually works.

This is the experimentation layer.

### 1.6 The Failure Mode Was Never Fixed; It Was Replicated

Whether a ROSCA fails informally through organiser fraud, or institutionally through auction mechanics and secondary market opacification, the root cause is the same: someone outside the group holds power that should belong to the collective. The circle breaks not because cooperative logic is flawed, but because an institution introduced single points of control that the cooperative logic was never designed to accommodate.

Every structural fix attempted by institutions reproduces the problem it claims to solve. Reputation systems gate access on identity and credit history. Auction mechanics gate timing on capital. Secondary market transfers gate continuity on administradora approval. Legal enforcement gates dispute resolution on jurisdictional access. Each intervention extends institutional sovereignty over a mechanism whose power derived precisely from operating outside institutional sovereignty.

### 1.7 DeFi Has Not Solved This Either

Decentralised finance has produced remarkable infrastructure for yield, lending, and capital markets. But it has not produced a savings primitive for ordinary people. The reasons are structural:

-   Yield-bearing stablecoins with competitive real-world rates require KYC gating at the issuance layer. Tokenised treasuries are accessible only to professional clients and licensed resellers.

-   Genuinely permissionless DeFi yield (sDAI, Aave, Compound) derives from crypto-native sources (borrowing demand, protocol incentives) that are volatile and collapse in downturns.

-   Undercollateralised lending in DeFi requires either identity exposure or reputation scoring. Both recreate surveillance-based access control.

-   Governance is token-weighted (one dollar, one vote), which means financial influence is proportional to wealth, the opposite of cooperative logic.

Most critically: DeFi has never built a cooperative savings primitive. Every existing protocol is designed around individual financial maximisation. There is no primitive whose success metric is community resilience, whose risk model is mutualized, or whose governance has structural limits on financial influence.

> [!IMPORTANT]
> **The Core Problem**
>
> *Billions of people save toward productive assets (a vehicle, equipment, property) and have no path to those assets except through institutional credit that may not serve them, or years of linear saving that delays access to what they are working toward. The mechanisms that historically solved this (savings circles, credit unions, ROSCAs, consórcios) have either broken on the organiser as single point of failure, or been institutionally captured into credit products that recreate the opacity and gatekeeping they were built to escape. DeFi has not built the infrastructure to fix this. The world needs a savings primitive that stays a savings primitive.*

## 2. The Principles

Mandinga Protocol is built on five principles that define every design decision. Together they answer the question: what would it mean to genuinely improve a financial primitive, instead of capturing it?

### Improving

The consórcio mechanic is not wrong. It is unfinished. The rotation logic is sound: every member contributes, every member receives the pool in turn, and the timing advantage is distributed rather than concentrated. What broke was the layer built on top of it: the auction, the administradora, the opaque fee structure, the secondary market. Mandinga improves the underlying primitive while refusing to replicate what corrupted it. No auction. No organiser. No opacity. The rotation logic, done properly.

### Exporting

What works in Brazil (the circle mechanic, the cooperative logic, the cultural preference for community-based savings) should not stay in Brazil. The consórcio was geographically and institutionally constrained from the moment it was formalised. The blockchain layer is the export mechanism: a savings circle built on-chain operates across borders, currencies, time zones, and jurisdictions without requiring any of them to be aligned. The communities that invented the ROSCA in every culture, independently, can now participate in a single primitive governed by the same logic.

### Approximating

A perfect circle requires perfect matching: every member with exactly the same installment amount, exactly the same duration, at exactly the same moment. Perfect matching rarely happens. The protocol approximates the ideal: it forms the best possible circle from available intent, not waiting for exact alignment that may never come. When enough people declare similar enough parameters, the kickoff algorithm closes the circle. Members who are slightly outside the best group receive suggestions to adjust their parameters and join a better match. The protocol continuously narrows the gap between intent and formation.

### Splitting

The fundamental act of a savings circle is splitting. A larger amount (the pool) is split into installments that a community of savers can sustain. Those installments, paid consistently over time, are what make the circle possible. Mandinga starts here: not with how much you want, but with how much you can put away, and for how long. That split defines your circle. The installment is the product.

### Adapting

A traditional consórcio binds you to an asset category from the day you join: a vehicle group, a real estate group, a specific ticket size with a specific administradora. Changing course means exiting and re-entering elsewhere, with penalties and delays. An on-chain savings circle carries no such constraint. The parameters that define your circle are declared at the start (installment size, duration) but what that credit activation enables can evolve as the protocol and the ecosystem of on-chain assets grow. Mandinga does not ask you to decide today what your savings will mean when your turn arrives.

## 3. The Solution: Mandinga Protocol

### 3.1 The Savings Account: Your Base Layer

Every member begins with a self-custodial savings account. Deposit a dollar-stable asset and it earns yield while it sits, automatically routed to on-chain yield sources, with no management required. The savings account is the base layer. All features of Mandinga Protocol sit on top of it. You can use it alone. The savings circle is an optional feature you activate when you are ready.

### 3.2 The Savings Circle: Start With What You Can Afford

The question is not *how much do you want?* It is *how much can you put away, and for how long?*

A member activates the savings circle feature by answering those two questions:

- **Installment**: how much can I contribute per period? (e.g., \$50 a month)
- **Duration**: for how long? (e.g., 12 months)

That is the entire input. From those two declarations, the protocol finds other people who can contribute the same amount over the same period. When enough matching intents exist, a circle forms. The pool (the amount each selected member's position reaches) is the installment multiplied by the circle size. Nobody declared that number. It emerged from the match.

The member selected first has their position marked as active: the full pool locked in the protocol and attributed to them, earning yield while obligations settle across the remaining rounds. The member selected last reaches that same activation after the full duration. The rotation distributes the timing advantage equally across all members. Every member is activated exactly once. No auctions. No bids. Verifiable on-chain randomness determines the order.

An active position is not a withdrawal. The pool remains in the protocol until the circle completes. What Mandinga is building toward is making that active position the basis for acquiring real assets (a vehicle, equipment, property) with the protocol holding the underlying stake until all obligations are met. The cooperative is the lienholder, not a bank. That direction is where the primitive points.

> [!NOTE]
> **Credit Access, Made Concrete**
>
> *Ten members each contributing \$100 a month create a \$1,000 pool. The member activated in round one has access to that pool nine months before the member activated in round ten. That nine-month gap is what the rotation distributes: not a yield premium but time. The asset nine months sooner, the business started nine months earlier, the vehicle working for nine more months.*
>
> *And unlike a traditional consórcio, the circle is not bound to a specific asset category from day one. The circle is defined by what you can save and for how long. What your active position enables can evolve as the protocol and the ecosystem of on-chain assets grow.*

#### The Minimum Installment: A Built-In Safety Net

Every installment has a floor. When joining a circle, a member can declare a minimum installment: the amount they can guarantee in any circumstances, even a difficult month. The default minimum is half the full installment.

If a member can only pay the minimum in a given round, the Safety Net Pool covers the difference. The circle does not pause. The member stays in. But from that moment, the member pays interest on the covered portion, a small, transparent fee that flows to the Safety Net Pool depositors who made the coverage possible.

This option can be elected in two ways:

- **At the start**: a member can declare upfront that they will use the minimum installment from day one. They pay interest on the covered half from the first round.
- **When needed**: a member pays full installments until they hit a difficult period, then activates the minimum option. Interest begins from that round.

This is not a loan. There is no credit check, no application, no approval. It is a structural feature of the circle: the Safety Net Pool holds capital specifically to enable this coverage, and the interest paid is the fair price for that capacity. The circle continues. The member's position is maintained. When they are selected, the debt is settled automatically before their net obligation is locked.

#### Enforcement Without Surveillance

The installment is an obligation, but enforcement is structural, not punitive. The minimum commitment is always half the installment: the Safety Net Pool covers the other half, so the amount any member is ever required to pay in a difficult round is exactly half of what they declared when joining.

The enforcement is architectural: the installment must be met each round, at minimum its covered half. There is no requirement to hold a specific balance at all times, no credit check, no identity tracking, and no permanent record. The only requirement is to pay the minimum when the round arrives. The pool always stands ready to cover the rest.

After selection, the Safety Net Pool is no longer involved. The full pool is locked to cover the selected member's remaining installment obligations automatically. The arithmetic guarantees this: the pool equals the total of all installments across the circle, and the remaining obligations after selection are always less than the pool received. The selected member keeps saving, and the credit activation is the return for doing so.

A member can also opt out of the Savings Circle feature entirely at any time. When they do, contributions already paid are returned to their savings account minus a small opt-out fee. The fee reflects the disruption to the circle and flows directly to the remaining members, not to a pool or protocol treasury. The savings account continues earning. The Savings Circle can be reactivated whenever they are ready.

The opt-out fee scales with how much credit access has already been captured. Leaving before selection costs little. The timing advantage has not yet been received. Leaving after selection costs more, proportional to the number of rounds the member has already benefited from early activation. This is not a penalty. It is the price of not following through on what you declared when you joined, paid to the people your exit disrupts.

**What happens if you cannot pay even half?**

This is a real scenario. Life happens. Before anything else, the protocol surfaces a question: is there a smaller installment you can sustain?

If yes, the protocol reallocates. The member moves to a smaller circle matching what they can actually afford. Their previous contributions transfer into the reallocation rather than returning to the savings account. The circle they leave may briefly carry a slightly smaller pool; the protocol works to bring in a replacement whose installment and remaining duration fit the open position, using the Safety Net Pool where needed. For the remaining members, the experience is minimal: a temporarily smaller pool while the replacement joins, then continuity. The circle is not broken. It is corrected.

If no, there is no installment, however small, that the member can commit to right now. The Savings Circle feature turns off. No more installments are owed. The contributions already paid are returned to the member's savings account, minus any debt owed to the Safety Net Pool for coverage already received. The member's obligation ends cleanly. The Savings Circle can be reactivated whenever they are ready.

You do not lose the money you put in. The design corrects, not punishes.

### 3.3 The Safety Net Pool: Making the Safety Net Possible

The Safety Net Pool is how the minimum installment option exists. Members with idle savings capacity deposit capital into the pool, lock it for a declared duration, and earn yield on it, the same yield their capital would earn in a standalone savings account. In exchange, that capital backs circle participants who need minimum installment coverage.

The return for pool depositors is straightforward: base yield on their locked capital, plus the interest paid by covered members. The risk is minimal: the coverage is always bounded by the installment amount, and the debt is always settled when the covered member receives their payout.

The Safety Net Pool is also the mechanism that eliminates the entry barrier entirely. A member does not need a large balance to join a circle. They need to be able to pay the minimum installment. The pool covers the gap until their savings build to full installment capacity.

### 3.4 Two Participation Strategies

| **Active Circle Participation** | **Safety Net Pool Deposit** |
|---|---|
| Join a circle matched to your installment | Deposit idle capital into the pool |
| Position activated when selected | Earn base yield plus interest from covered members |
| Earlier activation = sooner credit access | Lower upside, diversified across many circles |
| Capital tied to circle duration, redeemable on opt-out | Capital available to redeploy as circles complete |
| Maximises credit access timing advantage | Amplifies others' access while generating passive return |

The Safety Net Pool is not simply a financial instrument. It encodes the core principle of the cooperative model: those who have more capacity can amplify the access of those building toward capacity, and both benefit from the arrangement.

## 4. User Flows and Real Use Cases

### 4.1 Amara — Lagos, Nigeria

*Amara is a seamstress. She earns inconsistently but saves deliberately. She has never had a bank account that paid meaningful interest, and she has participated in a local ajo (rotating savings circle) for years. The organiser disappeared with the pot two years ago. She lost three months of contributions.*

Amara deposits \$120 into Mandinga Protocol using a mobile wallet. Her savings account immediately begins earning yield.

She activates the savings circle feature. The protocol asks: how much can you put away each month? She enters \$12. For how long? Ten months. The protocol finds nine other people with matching intent and forms a circle. The pool is \$120: \$12 multiplied by ten members.

She had been saving toward an industrial sewing machine: the kind of purchase that would take her ten more months of installments to reach alone, but that could expand her capacity and income immediately if she had it now.

In round three, Amara is selected. The full pool (\$120) locks to her position in the protocol, continuing to earn yield while her remaining obligations settle. She knows her income can be unpredictable, so she elected the minimum installment option at the start. On months when she can, she pays the full \$12. On difficult months, she pays \$6 and the Safety Net Pool covers the rest. A small interest charge appears in her position display, transparent, fair, and automatically settled when her turn arrived.

There is no organiser. The protocol is the organiser.

### 4.2 Rafael — São Paulo, Brazil

*Rafael is a delivery driver. He joined a motorcycle consórcio with a R\$15,000 carta de crédito, paying R\$280/month. He is in month 19 of a 60-month group. He has not been contemplated. He has watched other members win contemplation through lances he could not match. He has calculated that at his current pace, he will likely be contemplated somewhere between month 35 and 50, and will have paid the full administration fee regardless of when that happens.*

A friend tells him about Mandinga Protocol. He is sceptical. He associates crypto with speculation and volatility, not savings.

What changes his mind is the framing: *how much can you put away each month? For how long?* Rafael knows exactly what he can afford. He has been paying R\$280 a month for 19 months. He converts the equivalent of his monthly installment to a dollar-stable asset and activates the savings circle feature. The protocol matches him to a circle of similar intent.

Selection is by verifiable lottery. There is no lance mechanic. There is no auction. No one in the circle can purchase earlier access. In round six, Rafael is selected. His position is activated: the full pool attributed to him, locked in the protocol, earning yield while his remaining installments settle.

He is still in his original consórcio. It will eventually deliver a carta de crédito. But the bar was never *cheaper than financing*. The bar is: does the mechanism serve me, or does it serve the institution? For his next vehicle, Rafael will not use a consórcio.

### 4.3 Sofia — Buenos Aires, Argentina

*Sofia is a software developer with \$3,000 saved in dollar-stable assets. Argentina's inflation has taught her not to hold local currency. She wants stable yield without KYC requirements she does not trust.*

Sofia deposits into Mandinga Protocol. She participates actively in circles for two cycles, experiencing the credit activation mechanic firsthand.

In her third year, she shifts strategy. She deposits a portion of her savings into the Safety Net Pool, locking it for twelve months. Her capital earns the same yield it would in her savings account. But it also enables minimum installment coverage for circle participants who need it, and she earns the interest they pay on the covered portion.

Sofia now earns passive income while her capital amplifies the access of people who would otherwise be excluded from larger circles. This is not charity. It is cooperative savings, structured as a market.

### 4.4 A Diaspora Community — Coordinated Across Borders

*A family network spans three countries: members in Nairobi, London, and Toronto. They have historically coordinated a family chama using WhatsApp and informal trust. Twice in the last decade, members have defaulted on contributions. The emotional and financial cost to the group was significant.*

The family moves their circle to Mandinga Protocol. Each member declares how much they can put away and for how long. The protocol forms their circle. The rotation operates automatically across three time zones, three currencies (all bridged to dollar-stable assets at entry), and three jurisdictions.

The family has no organiser. They have a protocol. The social trust that made the original chama work is preserved: they chose each other, they know each other. But the structural vulnerability that broke it twice has been removed.

## 5. What Makes This Defipunk

The Ethereum Foundation's test for Defipunk DeFi is whether the thing could exist without Ethereum. Mandinga Protocol fails this test in the best possible way: it cannot exist anywhere else.

-   Could it exist on traditional banking rails? No. Banks require identity, report to credit bureaus, are geographically constrained, and extract surplus for shareholders.

-   Could it exist as a standard DAO? No. DAOs are token-weighted and fully transparent. Full transparency destroys the social grace that makes cooperative savings work.

-   Could it exist with a centralised yield manager? No. A human treasurer recreates the single point of failure that makes ROSCAs break.

-   Could the privacy layer exist on a standard public blockchain? No. Public ledgers would expose every member's balance and contribution history to the world, permanently and irreversibly.

-   Could the Safety Net Pool exist without decentralised enforcement? No. Coverage requires trustless structural guarantees that the backed position cannot be withdrawn while it is active.

Mandinga Protocol is also specifically aligned with the Ethereum Foundation's Defipunk criteria:

-   Permissionless access: anyone can interact with the core contracts without KYC or whitelisting.

-   Self-custody: users maintain custody at all times. The protocol holds principal in trust during circle participation, but withdrawal mechanics are enforced by code, not by a custodian.

-   Open source: all contract code is FLOSS-licensed and publicly auditable.

-   Privacy by default: balances, contribution history, and circle membership are shielded. The public ledger sees only cryptographic proofs of valid participation.

-   Governance with limits on financial influence: cooperative governance applies equal weight to all members regardless of deposit size. Protocol-level decisions are separated from circle-level decisions, each with appropriate governance scope.

-   Minimised oracle reliance: yield routing uses decentralised, manipulation-resistant oracle infrastructure for real-world rate data. The protocol is designed to continue functioning if any single data source fails.

## 6. The Broader Vision

Mandinga Protocol is a savings primitive that encodes cooperative credit logic into permissionless, self-custodial code. A new category of financial infrastructure, distinct from stablecoins, yield aggregators, and lending protocols.

The success metric is the number of circles that completed without a single point of failure, the number of people whose position was activated sooner than linear saving would have allowed, and the degree to which credit access expanded to people who previously had no path to it except through institutional gatekeeping. Not TVL. Not APY.

### From Activation to Ownership

Throughout this lightpaper, activation comes with an open question: the pool is locked in the protocol, your position is marked active — what do you do with it?

In v1, activation is the primitive. The circle ran without an organiser, without an auction, without anyone disappearing with the pot. That is the foundation.

What Mandinga builds toward from that foundation is the answer. An active position becomes a verifiable claim — proof of cooperative selection that can be used to acquire a real asset. A motorcycle for a delivery driver expanding what he can earn. Equipment for a seamstress growing her business. A home for a family that has been saving toward one. The protocol holds a stake in the underlying asset as lienholder until all remaining installments are settled. When the circle completes and obligations are met, ownership transfers fully to the member.

The cooperative is the lienholder. Not a bank. Not an administradora. Code.

This is the carta de crédito model without the institution. The consórcio understood that credit directed toward productive assets was more powerful than credit that dissolved into liquidity. What it never managed was doing that without an administradora in the middle, without an auction that let capital purchase earlier access, without a fee structure that charged the same regardless of when it served you. Mandinga Protocol is building the same destination — without any of that.

### The World It Points Toward

The vision is a world where the savings circle (the mechanism communities across every continent invented independently, for the same reason, across thousands of years) is finally structurally sound. Where it operates across borders, time zones, currencies, and jurisdictions without requiring any of them to be aligned. Where it is governed by the members who use it, not by the institution that administers it. Where what it enables (cooperative credit for productive assets, owned by no institution, captured by no administradora) grows with the ecosystem of on-chain assets and the communities building on top of it.

Savings circles have always been a public good. Mandinga Protocol is the infrastructure to make them one at scale.

> **Permissionless · Private · Solidary**
>
> *mandinga.protocol*
