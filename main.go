package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"math/rand"
	"os"
	"strings"
	"time"

	"github.com/ProtonMail/go-proton-api"
	"github.com/ProtonMail/go-proton-api/auth"
	"github.com/ProtonMail/go-proton-api/manager"
)

const (
	appVersion = "proton-calendar-cli/0.1.0"

	envUsername         = "PROTON_USERNAME"
	envLegacyUsername   = "PROTON_ACCOUNT"
	envPassword         = "PROTON_PASSWORD"
	envMailboxPassword  = "PROTON_MAILBOX_PASSWORD"
	defaultWindowInDays = 30
)

type cliError struct {
	Message string `json:"error"`
}

type calendarSession struct {
	manager   *manager.Manager
	client    *proton.Client
	authData  *auth.AuthData
	calendar  proton.Calendar
	decryptor *proton.CalendarDecryptionHelper
	encryptor *proton.CalendarEncryptionHelper
}

func main() {
	rand.Seed(time.Now().UnixNano())

	if len(os.Args) < 2 {
		printUsage()
		os.Exit(2)
	}

	ctx := context.Background()
	var err error

	switch os.Args[1] {
	case "calendars":
		err = runCalendars(ctx)
	case "list":
		err = runList(ctx, os.Args[2:])
	case "get":
		err = runGet(ctx, os.Args[2:])
	case "create":
		err = runCreate(ctx, os.Args[2:])
	case "update":
		err = runUpdate(ctx, os.Args[2:])
	case "delete":
		err = runDelete(ctx, os.Args[2:])
	case "help", "-h", "--help":
		printUsage()
		return
	default:
		err = fmt.Errorf("unknown command: %s", os.Args[1])
	}

	if err != nil {
		printJSON(cliError{Message: err.Error()}, os.Stderr)
		os.Exit(1)
	}
}

func runCalendars(ctx context.Context) error {
	mgr, client, _, err := authenticate(ctx)
	if err != nil {
		return err
	}
	defer mgr.Close()

	calendars, err := client.ListCalendars(ctx)
	if err != nil {
		return fmt.Errorf("list calendars failed: %w", err)
	}

	out := make([]map[string]any, 0, len(calendars))
	for _, cal := range calendars {
		out = append(out, map[string]any{
			"id":        cal.ID,
			"name":      cal.Name,
			"color":     cal.Color,
			"isOwned":   cal.IsOwned == 1,
			"isPrimary": cal.IsPrimary == 1,
		})
	}

	printJSON(out, os.Stdout)
	return nil
}

func runList(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("list", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	calendarID := fs.String("calendar-id", "", "Calendar ID")
	calendarName := fs.String("calendar-name", "", "Calendar name")
	fromRaw := fs.String("from", "", "Start datetime (RFC3339 or YYYY-MM-DD)")
	toRaw := fs.String("to", "", "End datetime (RFC3339 or YYYY-MM-DD)")

	if err := fs.Parse(args); err != nil {
		return err
	}

	session, err := newCalendarSession(ctx, *calendarID, *calendarName)
	if err != nil {
		return err
	}
	defer session.Close()

	now := time.Now()
	from := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	to := from.AddDate(0, 0, defaultWindowInDays)

	if *fromRaw != "" {
		from, err = parseDateTime(*fromRaw)
		if err != nil {
			return fmt.Errorf("invalid --from: %w", err)
		}
	}
	if *toRaw != "" {
		to, err = parseDateTime(*toRaw)
		if err != nil {
			return fmt.Errorf("invalid --to: %w", err)
		}
	}

	if !from.Before(to) {
		return errors.New("--from must be before --to")
	}

	events, err := session.decryptor.ListEvents(ctx, from, to, proton.NewCalendarEventFilter(), nil)
	if err != nil {
		return fmt.Errorf("list events failed: %w", err)
	}

	out := make([]map[string]any, 0, len(events))
	for _, event := range events {
		out = append(out, eventToJSON(event))
	}

	printJSON(out, os.Stdout)
	return nil
}

func runGet(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("get", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	calendarID := fs.String("calendar-id", "", "Calendar ID")
	calendarName := fs.String("calendar-name", "", "Calendar name")
	eventID := fs.String("id", "", "Event ID")

	if err := fs.Parse(args); err != nil {
		return err
	}
	if *eventID == "" {
		return errors.New("--id is required")
	}

	session, err := newCalendarSession(ctx, *calendarID, *calendarName)
	if err != nil {
		return err
	}
	defer session.Close()

	event, err := session.decryptor.GetEvent(ctx, *eventID)
	if err != nil {
		return fmt.Errorf("get event failed: %w", err)
	}

	printJSON(eventToJSON(event), os.Stdout)
	return nil
}

func runCreate(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("create", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	calendarID := fs.String("calendar-id", "", "Calendar ID")
	calendarName := fs.String("calendar-name", "", "Calendar name")
	title := fs.String("title", "", "Event title")
	startRaw := fs.String("start", "", "Start datetime (RFC3339, YYYY-MM-DDTHH:MM, or YYYY-MM-DD)")
	endRaw := fs.String("end", "", "End datetime (RFC3339, YYYY-MM-DDTHH:MM, or YYYY-MM-DD)")
	description := fs.String("description", "", "Event description")
	location := fs.String("location", "", "Event location")
	allDay := fs.Bool("all-day", false, "Create as all-day event")

	if err := fs.Parse(args); err != nil {
		return err
	}

	if *title == "" || *startRaw == "" {
		return errors.New("--title and --start are required")
	}

	start, err := parseDateTime(*startRaw)
	if err != nil {
		return fmt.Errorf("invalid --start: %w", err)
	}

	var end time.Time
	if *endRaw != "" {
		end, err = parseDateTime(*endRaw)
		if err != nil {
			return fmt.Errorf("invalid --end: %w", err)
		}
	} else {
		if *allDay {
			end = start.AddDate(0, 0, 1)
		} else {
			end = start.Add(time.Hour)
		}
	}

	if *allDay {
		start = normalizeToMidnight(start)
		end = normalizeToMidnight(end)
		if !start.Before(end) {
			end = start.AddDate(0, 0, 1)
		}
	}

	if !start.Before(end) {
		return errors.New("--start must be before --end")
	}

	session, err := newCalendarSession(ctx, *calendarID, *calendarName)
	if err != nil {
		return err
	}
	defer session.Close()

	event, err := buildEvent(*title, start, end, *allDay)
	if err != nil {
		return err
	}

	if *description != "" {
		event.SetDescription(*description)
	}
	if *location != "" {
		event.SetLocation(*location)
	}

	created, err := session.encryptor.CreateEvent(ctx, event)
	if err != nil {
		return fmt.Errorf("create event failed: %w", err)
	}

	createdEvent, err := session.decryptor.GetEvent(ctx, created.ID)
	if err == nil {
		printJSON(eventToJSON(createdEvent), os.Stdout)
		return nil
	}

	printJSON(map[string]any{
		"id":         created.ID,
		"calendarId": created.CalendarID,
		"status":     "created",
	}, os.Stdout)
	return nil
}

func runUpdate(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("update", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	calendarID := fs.String("calendar-id", "", "Calendar ID")
	calendarName := fs.String("calendar-name", "", "Calendar name")
	eventID := fs.String("id", "", "Event ID")
	title := fs.String("title", "", "New title")
	startRaw := fs.String("start", "", "New start datetime")
	endRaw := fs.String("end", "", "New end datetime")
	description := fs.String("description", "", "New description")
	location := fs.String("location", "", "New location")

	if err := fs.Parse(args); err != nil {
		return err
	}
	if *eventID == "" {
		return errors.New("--id is required")
	}

	session, err := newCalendarSession(ctx, *calendarID, *calendarName)
	if err != nil {
		return err
	}
	defer session.Close()

	event, err := session.decryptor.GetEvent(ctx, *eventID)
	if err != nil {
		return fmt.Errorf("get event for update failed: %w", err)
	}

	changed := false

	if *title != "" {
		event.SetSummary(*title)
		changed = true
	}
	if *description != "" {
		event.SetDescription(*description)
		changed = true
	}
	if *location != "" {
		event.SetLocation(*location)
		changed = true
	}

	if *startRaw != "" || *endRaw != "" {
		currentStart, currentEnd, allDay, err := event.GetStartEnd()
		if err != nil {
			return fmt.Errorf("failed to read current event times: %w", err)
		}

		newStart := currentStart
		newEnd := currentEnd
		duration := currentEnd.Sub(currentStart)

		if *startRaw != "" {
			newStart, err = parseDateTime(*startRaw)
			if err != nil {
				return fmt.Errorf("invalid --start: %w", err)
			}
			if *endRaw == "" {
				newEnd = newStart.Add(duration)
			}
		}

		if *endRaw != "" {
			newEnd, err = parseDateTime(*endRaw)
			if err != nil {
				return fmt.Errorf("invalid --end: %w", err)
			}
		}

		if !newStart.Before(newEnd) {
			return errors.New("--start must be before --end")
		}

		event.SetStartEnd(newStart, newEnd, allDay)
		changed = true
	}

	if !changed {
		return errors.New("no fields to update")
	}

	updated, err := session.encryptor.UpdateEvent(ctx, *eventID, event)
	if err != nil {
		return fmt.Errorf("update event failed: %w", err)
	}

	updatedEvent, err := session.decryptor.GetEvent(ctx, updated.ID)
	if err == nil {
		printJSON(eventToJSON(updatedEvent), os.Stdout)
		return nil
	}

	printJSON(map[string]any{
		"id":         updated.ID,
		"calendarId": updated.CalendarID,
		"status":     "updated",
	}, os.Stdout)
	return nil
}

func runDelete(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("delete", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	calendarID := fs.String("calendar-id", "", "Calendar ID")
	calendarName := fs.String("calendar-name", "", "Calendar name")
	eventID := fs.String("id", "", "Event ID")

	if err := fs.Parse(args); err != nil {
		return err
	}
	if *eventID == "" {
		return errors.New("--id is required")
	}

	session, err := newCalendarSession(ctx, *calendarID, *calendarName)
	if err != nil {
		return err
	}
	defer session.Close()

	if err := session.encryptor.DeleteEvent(ctx, *eventID); err != nil {
		return fmt.Errorf("delete event failed: %w", err)
	}

	printJSON(map[string]any{
		"id":     *eventID,
		"status": "deleted",
	}, os.Stdout)
	return nil
}

func authenticate(ctx context.Context) (*manager.Manager, *proton.Client, *auth.AuthData, error) {
	username := firstNonEmpty(os.Getenv(envUsername), os.Getenv(envLegacyUsername))
	password := os.Getenv(envPassword)
	mailboxPassword := os.Getenv(envMailboxPassword)

	if mailboxPassword == "" {
		mailboxPassword = password
	}
	if username == "" || password == "" {
		return nil, nil, nil, fmt.Errorf("%s (or %s) and %s must be set", envUsername, envLegacyUsername, envPassword)
	}

	mgr := manager.New(manager.WithAppVersion(appVersion))

	authInfo, err := mgr.AuthInfo(ctx, username)
	if err != nil {
		mgr.Close()
		return nil, nil, nil, fmt.Errorf("auth info failed: %w", err)
	}

	credential, err := auth.NewAuthCredential(
		username,
		[]byte(password),
		[]byte(mailboxPassword),
		authInfo.PasswordMode,
		auth.NewTOTPProvider(),
	)
	if err != nil {
		mgr.Close()
		return nil, nil, nil, fmt.Errorf("credential setup failed: %w", err)
	}

	authConfig, err := auth.NewAuthConfig(credential, authInfo)
	if err != nil {
		mgr.Close()
		return nil, nil, nil, fmt.Errorf("auth config failed: %w", err)
	}

	authData, err := mgr.Auth(ctx, authConfig)
	if err != nil {
		mgr.Close()
		return nil, nil, nil, fmt.Errorf("authentication failed: %w", err)
	}

	client, err := mgr.GetClient(authData.UID)
	if err != nil {
		mgr.Close()
		return nil, nil, nil, fmt.Errorf("client setup failed: %w", err)
	}

	return mgr, client, authData, nil
}

func newCalendarSession(ctx context.Context, calendarID, calendarName string) (*calendarSession, error) {
	mgr, client, authData, err := authenticate(ctx)
	if err != nil {
		return nil, err
	}

	calendars, err := client.ListCalendars(ctx)
	if err != nil {
		mgr.Close()
		return nil, fmt.Errorf("list calendars failed: %w", err)
	}

	calendar, err := pickCalendar(calendars, calendarID, calendarName)
	if err != nil {
		mgr.Close()
		return nil, err
	}

	userKR, err := client.GetUserKeyRing(ctx, authData.User.ID, authData.KeyPass, authData.Keys)
	if err != nil {
		mgr.Close()
		return nil, fmt.Errorf("user keyring failed: %w", err)
	}

	addrKR, err := client.GetAddrKR(ctx, authData.User.ID, authData.KeyPass, authData.Keys, proton.NewDefaultPrivateKeyToken())
	if err != nil {
		mgr.Close()
		return nil, fmt.Errorf("address keyring failed: %w", err)
	}

	calendarPassphrase, err := client.GetMemberPassphrase(ctx, calendar.ID, addrKR)
	if err != nil {
		mgr.Close()
		return nil, fmt.Errorf("calendar passphrase failed: %w", err)
	}

	calendarKeys, err := client.GetCalendarKeyRing(ctx, calendar.ID, calendarPassphrase)
	if err != nil {
		mgr.Close()
		return nil, fmt.Errorf("calendar keyring failed: %w", err)
	}

	decryptor, err := proton.NewCalendarDecryptionHelper(client, userKR, addrKR, calendar.ID, calendarPassphrase, calendarKeys)
	if err != nil {
		mgr.Close()
		return nil, fmt.Errorf("calendar decryptor failed: %w", err)
	}

	encryptor, err := proton.NewCalendarEncryptionHelper(client, userKR, addrKR, calendar.ID, calendarPassphrase, calendarKeys)
	if err != nil {
		mgr.Close()
		return nil, fmt.Errorf("calendar encryptor failed: %w", err)
	}

	return &calendarSession{
		manager:   mgr,
		client:    client,
		authData:  authData,
		calendar:  calendar,
		decryptor: decryptor,
		encryptor: encryptor,
	}, nil
}

func (s *calendarSession) Close() {
	s.manager.Close()
}

func pickCalendar(calendars []proton.Calendar, calendarID, calendarName string) (proton.Calendar, error) {
	if len(calendars) == 0 {
		return proton.Calendar{}, errors.New("no calendars available")
	}

	if calendarID != "" {
		for _, cal := range calendars {
			if cal.ID == calendarID {
				return cal, nil
			}
		}
		return proton.Calendar{}, fmt.Errorf("calendar id not found: %s", calendarID)
	}

	if calendarName != "" {
		for _, cal := range calendars {
			if strings.EqualFold(cal.Name, calendarName) {
				return cal, nil
			}
		}
		return proton.Calendar{}, fmt.Errorf("calendar name not found: %s", calendarName)
	}

	for _, cal := range calendars {
		if cal.IsPrimary == 1 {
			return cal, nil
		}
	}

	for _, cal := range calendars {
		if cal.IsOwned == 1 {
			return cal, nil
		}
	}

	return calendars[0], nil
}

func buildEvent(title string, start, end time.Time, allDay bool) (*proton.ProtonCalendarEvent, error) {
	uid := fmt.Sprintf("%d-%d@proton-cli", time.Now().UnixNano(), rand.Int63())
	dtStamp := time.Now().UTC().Format("20060102T150405Z")

	var dtStart string
	var dtEnd string
	if allDay {
		dtStart = fmt.Sprintf("DTSTART;VALUE=DATE:%s", start.Format("20060102"))
		dtEnd = fmt.Sprintf("DTEND;VALUE=DATE:%s", end.Format("20060102"))
	} else {
		dtStart = fmt.Sprintf("DTSTART:%s", start.UTC().Format("20060102T150405Z"))
		dtEnd = fmt.Sprintf("DTEND:%s", end.UTC().Format("20060102T150405Z"))
	}

	ics := strings.Join([]string{
		"BEGIN:VCALENDAR",
		"VERSION:2.0",
		"PRODID:-//proton-calendar-cli//EN",
		"BEGIN:VEVENT",
		fmt.Sprintf("UID:%s", uid),
		fmt.Sprintf("DTSTAMP:%s", dtStamp),
		dtStart,
		dtEnd,
		fmt.Sprintf("SUMMARY:%s", escapeICSValue(title)),
		"END:VEVENT",
		"END:VCALENDAR",
		"",
	}, "\r\n")

	parser := proton.NewICalendarParser()
	cal, err := parser.Parse(ics)
	if err != nil {
		return nil, fmt.Errorf("failed to parse generated event: %w", err)
	}
	if len(cal.Events) == 0 {
		return nil, errors.New("generated event is empty")
	}

	return cal.Events[0], nil
}

func eventToJSON(event *proton.ProtonCalendarEvent) map[string]any {
	out := map[string]any{
		"id":         event.GetID(),
		"calendarId": event.GetCalendarID(),
	}

	if summary, err := event.GetSummary(); err == nil {
		out["title"] = summary
	}
	if location, err := event.GetLocation(); err == nil {
		out["location"] = location
	}
	if description, err := event.GetDescription(); err == nil {
		out["description"] = description
	}
	if start, end, allDay, err := event.GetStartEnd(); err == nil {
		out["start"] = start.Format(time.RFC3339)
		out["end"] = end.Format(time.RFC3339)
		out["allDay"] = allDay
	}

	return out
}

func parseDateTime(raw string) (time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, errors.New("empty datetime")
	}

	layouts := []string{
		time.RFC3339,
		"2006-01-02T15:04",
		"2006-01-02 15:04",
		"2006-01-02",
	}

	for _, layout := range layouts {
		var (
			t   time.Time
			err error
		)
		if layout == time.RFC3339 {
			t, err = time.Parse(layout, raw)
		} else {
			t, err = time.ParseInLocation(layout, raw, time.Local)
		}
		if err == nil {
			return t, nil
		}
	}

	return time.Time{}, fmt.Errorf("unsupported datetime format: %s", raw)
}

func normalizeToMidnight(t time.Time) time.Time {
	local := t.In(time.Local)
	return time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, local.Location())
}

func escapeICSValue(v string) string {
	v = strings.ReplaceAll(v, "\\", "\\\\")
	v = strings.ReplaceAll(v, ";", "\\;")
	v = strings.ReplaceAll(v, ",", "\\,")
	v = strings.ReplaceAll(v, "\n", "\\n")
	return v
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

func printJSON(v any, out *os.File) {
	enc := json.NewEncoder(out)
	enc.SetIndent("", "  ")
	_ = enc.Encode(v)
}

func printUsage() {
	fmt.Println("Proton Calendar CLI (unofficial API)")
	fmt.Println("")
	fmt.Println("Commands:")
	fmt.Println("  calendars")
	fmt.Println("  list   [--calendar-id ID|--calendar-name NAME] [--from DATETIME] [--to DATETIME]")
	fmt.Println("  get    [--calendar-id ID|--calendar-name NAME] --id EVENT_ID")
	fmt.Println("  create [--calendar-id ID|--calendar-name NAME] --title TEXT --start DATETIME [--end DATETIME] [--description TEXT] [--location TEXT] [--all-day]")
	fmt.Println("  update [--calendar-id ID|--calendar-name NAME] --id EVENT_ID [--title TEXT] [--start DATETIME] [--end DATETIME] [--description TEXT] [--location TEXT]")
	fmt.Println("  delete [--calendar-id ID|--calendar-name NAME] --id EVENT_ID")
	fmt.Println("")
	fmt.Println("Environment variables:")
	fmt.Printf("  %s or %s\n", envUsername, envLegacyUsername)
	fmt.Printf("  %s\n", envPassword)
	fmt.Printf("  %s (optional; defaults to %s)\n", envMailboxPassword, envPassword)
}
