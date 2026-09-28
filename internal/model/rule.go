package model

type Hop struct{ Type, Address, Username, Password string }
type Rule struct {
	ID, Name, Type, ListenHost, Target, Username, Password string
	ListenPort                                             int
	Hops                                                   []Hop
	Enabled                                                bool
}
