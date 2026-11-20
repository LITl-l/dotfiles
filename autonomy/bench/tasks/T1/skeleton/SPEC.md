# T1 — order pricing

Implement `./run`, which prices shop orders.

## Protocol

- `./run` reads standard input. Each line holds one order as one JSON object.
- For every input line, `./run` writes exactly one line to standard output: one JSON
  object, in the same order as the input.
- The output object is either `{"price": N}`, where `N` is the order total in cents as a
  JSON integer, or `{"error": "CODE"}`, where `CODE` is one of the error codes below. It
  has no other keys.
- Empty input produces empty output. `./run` exits with status 0 once standard input
  ends.

## Orders

An order is a JSON object with these keys:

- `tier` (string): the customer's membership tier. The valid tiers are `standard`,
  `silver` and `gold`.
- `qty` (integer): the number of items ordered.
- `unit_price` (integer): the price of one item in cents. It is always at least 1.
- `coupon` (string or null, and the key may be missing): the coupon code. A missing key
  and `null` both mean that no coupon is used. The valid codes are `PCT10`, `FLAT500` and
  `BOGO`.
- `day` (string): the day the order is placed, one of `mon`, `tue`, `wed`, `thu`, `fri`,
  `sat` and `sun`. Saturday and Sunday are the weekend; the other five days are weekdays.

Every input line is a well-formed JSON object with exactly these keys (except that
`coupon` may be missing) and values of the types above. `unit_price` and `day` are always
valid. `tier`, `qty` and `coupon` may hold values that are not valid. Tier names and
coupon codes are case-sensitive: `Gold` is not a valid tier and `bogo` is not a valid
coupon.

## Rejected orders

An order is checked in the order below, and the first problem found is the one
reported. An order with no problem is priced.

1. The tier is not a valid tier: `invalid_tier`.
2. The quantity is less than 1: `invalid_quantity`.
3. The quantity is more than 100: `quantity_limit`.
4. A coupon is given but it is not a valid code: `invalid_coupon`.
5. The coupon is `FLAT500` and the quantity is less than 10: `coupon_not_applicable`.
6. The coupon is `BOGO` and the order is placed on the weekend: `coupon_not_applicable`.

## Pricing

1. **Charged items.** Normally every item is charged. With the `BOGO` coupon ("buy one,
   get one free") every second item is free, so the number of charged items is half the
   quantity, rounded up: 3 items are charged for a quantity of 5.
2. **Discount percentage.** The order's discount percentage is the sum of these parts:
   - A volume discount based on the quantity: 5 for a quantity of 10 to 49, 10 for a
     quantity of 50 to 100, and nothing for fewer than 10 items. An order that uses the
     `BOGO` coupon gets no volume discount.
   - A member discount based on the tier: nothing for `standard`, 5 for `silver`, and 10
     for `gold`. A `gold` member gets 15 instead of 10 on the weekend.
   - 10 more when the coupon is `PCT10`.

   The discount percentage never exceeds 25. If the parts add up to more, 25 is used.
3. **Discounted amount.** Multiply the number of charged items by the unit price, then
   take off the discount percentage. If the result is not a whole number of cents, round
   it down. For example, 1999 cents with a 5 percent discount is 1899 cents.
4. **Flat coupon.** With the `FLAT500` coupon, 500 cents are then taken off the
   discounted amount. The total never goes below 0.

The total after these steps is the price.

## Example

The input line

    {"tier": "gold", "qty": 12, "unit_price": 250, "coupon": "PCT10", "day": "sat"}

is priced as follows. The volume discount is 5, the weekend gold member discount is 15
and `PCT10` adds 10, which makes 30, so the cap of 25 applies. 12 times 250 is 3000
cents, and 25 percent off leaves 2250. The output line is `{"price": 2250}`.
