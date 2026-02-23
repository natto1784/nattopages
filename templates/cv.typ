#set page(
  paper: "a4",
  margin: 0.5in,
)

#set text(size: 0.9em)

#set par(justify: false, spacing: 0.5em)

#show par: it => [
  #v(1pt)
  #it
  #v(1pt)
]

#show heading.where(level: 1): it => [
  #set text(size: 1.1em, weight: "regular")
  #v(2pt)
  #smallcaps(it.body)
]

#show heading.where(level: 2): it => [
  #v(2pt)
  #set text(size: 1em, weight: "bold")
  #it.body
  #v(0pt)
]

#show heading.where(level: 3): it => [
  #v(3pt)
  #set text(size: 0.9em, weight: "bold")
  #it.body
  #v(1pt)
]

#set list(indent: 0pt, marker: ([•], [◦]), spacing: 6pt)

#show list: it => [
  #set text(size: 0.9em)
  #v(1pt)
  #it
]

#show link: set text(fill: rgb(209, 45, 127))

#set table(stroke: none, inset: (y: 4pt))
#show table.cell: set align(left)
#show figure.where(kind: table): set align(left)

$body$