package celtype

import "time"

type Deadline struct {
	at time.Time
}

func NewDeadline(deadlineMs int64) Deadline {
	return Deadline{at: time.Now().Add(time.Duration(deadlineMs) * time.Millisecond)}
}

func (d Deadline) Exceeded() bool {
	return !d.at.IsZero() && !time.Now().Before(d.at)
}
