// Copyright (c) 2018 The Ecosystem Authors
// Distributed under the MIT software license, see the accompanying
// file COPYING or or or http://www.opensource.org/licenses/mit-license.php


/*
Show nicely (but simple) formatted HTML error pages (or respond with JSON
if the appropriate `Accept` header is set)) for the http package.
*/
package http

import (
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"strings"
	"time"

	"github.com/ecosystem/go-ecosystem/log"
	"github.com/ecosystem/go-ecosystem/metrics"
	"github.com/ecosystem/go-ecosystem/swarm/api"
)

//templateMap holds a mapping of an HTTP error code to a template
var templateMap map[int]*template.Template
var caseErrors []CaseError

//metrics variables
var (
	htmlCounter = metrics.NewRegisteredCounter("api.http.errorpage.html.count", nil)
	jsonCounter = metrics.NewRegisteredCounter("api.http.errorpage.json.count", nil)
)

//parameters needed for formatting the correct HTML page
type ErrorParams struct {
	Msg       string
	Code      int
	Timestamp string
	template  *template.Template
	Details   template.HTML
}

//a custom error case struct that would be used to store validators and
//additional error info to display with client responses.
type CaseError struct {
	Validator func(*Request) bool
	Msg       func(*Request) string
}

//we init the error handling right on boot time, so lookup and http response is fast
func init() {
	initErrHandling()
}

func initErrHandling() {
	//pages are saved as strings - get these strings
	genErrPage := GetGenericErrorPage()
	notFoundPage := GetNotFoundErrorPage()
	multipleChoicesPage := GetMultipleChoicesErrorPage()
	//map the codes to the available pages
	tnames := map[int]string{
		0: genErrPage, //default
		http.StatusBadRequest:          genErrPage,
		http.StatusNotFound:            notFoundPage,
		http.StatusMultipleChoices:     multipleChoicesPage,
		http.StatusInternalServerError: genErrPage,
	}
	templateMap = make(map[int]*template.Template)
	for code, tname := range tnames {
		//assign formatted HTML to the code
		templateMap[code] = template.Must(template.New(fmt.Sprintf("%d", code)).Parse(tname))
	}

	caseErrors = []CaseError{
		{
			Validator: func(r *Request) bool { return r.uri != nil && r.uri.Addr != "" && strings.HasPrefix(r.uri.Addr, "0x") },
			Msg: func(r *Request) string {
				uriCopy := r.uri
				uriCopy.Addr = strings.TrimPrefix(uriCopy.Addr, "0x")
				return fmt.Sprintf(`The requested hash seems to be prefixed with '0x'. You will be redirected to the correct URL within 5 seconds.<br/>
			Please click <a href='%[1]s'>here</a> if your browser does not redirect you.<script>setTimeout("location.href='%[1]s';",5000);</script>`, "/"+uriCopy.String())
			},
		}}
}

//ValidateCaseErrors is a method that process the request object through certain validators
//that assert if certain conditions are met for further information to log as an error
func ValidateCaseErrors(r *Request) string {
	for _, err := range caseErrors {
		if err.Validator(r) {
			return err.Msg(r)
		}
	}

	return ""
}

//ShowMultipeChoices is used when a user requests a resource in a manifest which results
//in ambiguous results. It returns a HTML page with clickable links of each of the entry
//in the manifest which fits the request URI ambiguity.
//For example, if the user requests bzz:/<hash>/read and that manifest contains entries
//"readme.md" and "readinglist.txt", a HTML page is returned with this two links.
//This only applies if the manifest has no default entry
func ShowMultipleChoices(w http.ResponseWriter, r *Request, list api.ManifestList) {
	msg := ""
	if list.Entries == nil {
		ShowError(w, r, "Could not resolve", http.StatusInternalServerError)
		return
	}
	//make links relative
	//requestURI comes with the prefix of the ambiguous path, e.g. "read" for "readme.md" and "readinglist.txt"
	//to get clickable links, need to remove the ambiguous path, i.e. "read"
	idx := strings.LastIndex(r.RequestURI, "/")
	if idx == -1 {
		ShowError(w, r, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	//remove ambiguous part
	base := r.RequestURI[:idx+1]
	for _, e := range list.Entries {
		//create clickable link for each entry
		msg += "<a href='" + base + e.Path + "'>" + e.Path + "</a><br/>"
	}
	respond(w, &r.Request, &ErrorParams{
		Code:      http.StatusMultipleChoices,
		Details:   template.HTML(msg),
		Timestamp: time.Now().Format(time.RFC1123),
		template:  getTemplate(http.StatusMultipleChoices),
	})
}

//ShowError is used to show an HTML error page to a client.
//If there is an `Accept` header of `application/json`, JSON will be returned instead
//The function just takes a string message which will be displayed in the error page.
//The code is used to evaluate which template will be displayed
//(and return the correct HTTP status code)
func ShowError(w http.ResponseWriter, r *Request, msg string, code int) {
	additionalMessage := ValidateCaseErrors(r)
	if code == http.StatusInternalServerError {
		log.Error(msg)
	}
	respond(w, &r.Request, &ErrorParams{
		Code:      code,
		Msg:       msg,
		Details:   template.HTML(additionalMessage),
		Timestamp: time.Now().Format(time.RFC1123),
		template:  getTemplate(code),
	})
}

//evaluate if client accepts html or json response
func respond(w http.ResponseWriter, r *http.Request, params *ErrorParams) {
	w.WriteHeader(params.Code)
	if r.Header.Get("Accept") == "application/json" {
		respondJson(w, params)
	} else {
		respondHtml(w, params)
	}
}

//return a HTML page
func respondHtml(w http.ResponseWriter, params *ErrorParams) {
	htmlCounter.Inc(1)
	err := params.template.Execute(w, params)
	if err != nil {
		log.Error(err.Error())
	}
}

//return JSON
func respondJson(w http.ResponseWriter, params *ErrorParams) {
	jsonCounter.Inc(1)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(params)
}

//get the HTML template for a given code
func getTemplate(code int) *template.Template {
	if val, tmpl := templateMap[code]; tmpl {
		return val
	} else {
		return templateMap[0]
	}
}
