# Review theme analysis used for docs/market-research.md.
# Input: all_reviews.json (App Store RSS reviews: rating, title, text). Run: python3 review_themes.py

import json,re,collections,sys
rows=json.load(open("all_reviews.json"))
names={"1224672532":"HyperJar","1495077102":"Snoop","548615579":"Spending Tracker","916741290":"Pennies","1010865877":"YNAB","1130616675":"Rocket Money","1447330651":"Copilot","1459319842":"Monarch","471112395":"Goodbudget","1621020173":"Fleur","635861140":"Spendee","1525179720":"Spending Tracker 2","1447274646":"Cleo","1567346791":"Financielle","1212024409":"Monefy","560481810":"Money Manager","936422955":"Buddy","1009323715":"Debt Payoff Planner","1240710873":"Debt Payoff Box","1352782733":"Bills Organizer"}
T={
 "Bank sync broken/unreliable":r"\b(sync|syncing|connect(ion|ed|ing)?|disconnect|plaid|link(ed|ing)? (my )?(bank|account)|bank (feed|connection)|re-?link|reconnect|won'?t (load|update) transactions|missing transactions|duplicate)",
 "Price / subscription / paywall":r"\b(subscription|price|pricing|expensive|paywall|premium|pay (for|to)|per (month|year)|£\d|\$\d|free trial|charged|refund|cancel|upsell|ads?\b|advert)",
 "Bugs / crashes / data loss":r"\b(crash|bug|glitch|freez|not working|doesn'?t work|lost (all )?(my )?data|data (was )?(lost|gone|deleted)|deleted|wiped|broken|won'?t open|error)",
 "Hard to use / learning curve":r"\b(confus|complicated|learning curve|not intuitive|unintuitive|hard to (use|understand|navigate)|clunky|overwhelm|too many (steps|features))",
 "Update made it worse / removed feature":r"\b(update|redesign|new version|latest version).{0,60}(worse|ruin|removed|gone|terrible|hate|broke)",
 "Categorisation wrong / tedious":r"\b(categor|recategor|mis-?categor)",
 "Privacy / security worry":r"\b(privacy|private|secur|data (sharing|sold|selling)|trust|face ?id|passcode|lock)",
 "Customer support poor":r"\b(support|customer service|no (reply|response)|chatbot|ignored)",
 "Manual entry / quick add":r"\b(manual(ly)?|enter(ing)? (each|every|my)|input|quick(ly)? (add|log|enter)|easy to (add|enter|log))",
 "Bills / reminders / due dates":r"\b(bill|reminder|due date|notification|remind|direct debit|recurring|subscriptions? (track|reminder))",
 "Debt payoff / snowball / avalanche":r"\b(debt|snowball|avalanche|payoff|pay off|loan|credit card|interest)",
 "Charts / insights / reports":r"\b(chart|graph|insight|report|analytic|visual|breakdown|pie)",
 "Payday / custom budget period":r"\b(payday|pay day|pay cycle|paid (on|every)|start (date|day) of (the )?month|custom (period|month|start)|4[- ]weekly|four[- ]weekly|fortnight|biweekly|bi-weekly)",
 "Sharing / couples / household":r"\b(partner|spouse|wife|husband|couple|share(d)? (with|budget|account)|household|family)",
 "Export / backup / multi-device":r"\b(export|csv|backup|back up|icloud|sync between|multiple devices|ipad|web (version|app)|desktop|mac app)",
 "Forecast / future balance / safe to spend":r"\b(forecast|project(ion|ed)|future balance|left to spend|safe to spend|how much (i have|is left|can spend)|until payday|cash ?flow)",
 "Savings goals / pots":r"\b(goal|pot|jar|saving(s)? (target|goal))",
 "Habit / motivation / awareness":r"\b(aware|mindful|accountab|motivat|habit|stress|anxiety|peace of mind|in control|control of my|changed my life|life ?changing)",
}
def theme_counts(subset):
    c=collections.Counter()
    for r in subset:
        t=(r["title"]+" "+r["text"]).lower()
        for k,p in T.items():
            if re.search(p,t): c[k]+=1
    return c
low=[r for r in rows if r["rating"]<=2]; high=[r for r in rows if r["rating"]>=4]
print("Total",len(rows),"low",len(low),"high",len(high))
cl,ch=theme_counts(low),theme_counts(high)
print("\n%-42s %8s %8s"%("Theme","%low(1-2★)","%high(4-5★)"))
for k in T: print("%-42s %7.1f%% %7.1f%%"%(k,100*cl[k]/len(low),100*ch[k]/len(high)))
json.dump({"names":names},open("names.json","w"))
