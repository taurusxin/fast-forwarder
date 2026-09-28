package storage

import (
	"database/sql"
	"encoding/json"
	"github.com/taurusxin/fast-forwarder/internal/model"
)

func ReadRules(db *sql.DB) ([]model.Rule, error) {
	rows, err := db.Query("SELECT body FROM rules ORDER BY rowid")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []model.Rule{}
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			return nil, err
		}
		var v model.Rule
		if err := json.Unmarshal([]byte(s), &v); err != nil {
			return nil, err
		}
		if v.Hops == nil {
			v.Hops = []model.Hop{}
		}
		out = append(out, v)
	}
	return out, rows.Err()
}
