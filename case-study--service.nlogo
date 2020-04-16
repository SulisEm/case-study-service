breed [tokens token]
breed [operators operator]

tokens-own [
  state            ;; "M": Moving (to the next Task/Queue) - "W": Waiting (on the Task)  - "S": Service (having the Service of the Task)
  next-task        ;; name of the next task
  destination      ;; where the agent have to move
  arrival-time     ;; the ticks/time at the arrival
  work-durat-task  ;; the amount of time/duration of the work on the task
]

operators-own  [
  state            ;; "L": Looking - "M": Moving - "W": Waiting- "S": Service - "P": Pause
  work-with        ;; the agent the operator is going to serve (or to work with)
  destination      ;; where the agent have to move
  next-task        ;; name of the next task
  work-durat-task  ;; the amount of time/duration of the work on the task
]

patches-own [
  typeForm         ;; "task" or "queue"
  name             ;; name of the task or queue (i.e., "Take number" or "queue Take number")

  ;if typeForm is "task":
  name-queue       ;; the name of the patch where people have to wait before to enter the task (e.g., "queue Take number")
  pstate           ;; "free" or "busy"
  queue            ;; the list of tokens interested in enter the task (as a queue)

  ;duration variables
  duration-triang  ;; if filled, the three values of the triang.dist. in a string separated by a '*' char (e.g.,"2.5*3*3.5")
  duration-mean    ;; if filled, the average duration (normal distribution)
  duration-devst   ;; if filled, the st.dev. duration (normal distribution)

  ;if typeForm is "queue":
  next-task-of-queue
]

globals [
  monit-dismissed  ;; monitor to show dismissed patients
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;   SETUP  procedures  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  ca

  setup-world       ;; setup the world/patches

  setup-labels      ;; add labels on the diagram to tasks and start/end events

  setup-operators   ;; create and initialize variables of the operators

  setup-monitors    ;; initialize monitors

  reset-ticks       ;; initialize the clock/time of the simulation
end

to setup-world
  ;; initialize patches to have a white background, a blue color of the patch labels, reset all other values (e.g., no name, no pstate, and so on)
  ask patches [ set pcolor 9.9 set plabel-color blue set name "" set pstate ""
  set duration-triang "" set duration-mean "" set duration-devst "" set typeForm "" set name-queue ""
  ]

  ;; initialize each task with their: position (absolute coordinates pxcor and pycor) / type ("task" or "queue") / name (name of the patch) / (background) color of the patch / duration times
  ask patches with [ pxcor = -12 and pycor = 9 ] [ set pcolor 8 set name "Arrival customer" set typeForm "task" ]
  ask patches with [ pxcor = 0  and pycor = 10 ] [ set pcolor 38 set name "Queue-TakeNumber"  set typeForm "queue" set next-task-of-queue "Take number"]
  ask patches with [ pxcor = 12  and pycor = 9 ] [ set pcolor 78 set name "Take number" set duration-triang "" set duration-mean 5 set duration-devst 0.1 set typeForm "AutomaticTask" set name-queue "Queue-TakeNumber"]
  ask patches with [ pxcor = 13  and pycor = 1 ] [ set pcolor 38 set name "Queue-Registration"  set typeForm "queue" set next-task-of-queue "Registration"]
  ask patches with [ pxcor = 12 and pycor = -7 ] [ set pcolor 97 set name "Registration" set duration-triang "2.5*5*9.5"  set typeForm "HumanTask" set name-queue "Queue-Registration"]
  ask patches with [ pxcor = 4  and pycor = -4 ] [ set pcolor 38 set name "Queue-TicketPayment"  set typeForm "queue" set next-task-of-queue "Ticket payment"]
  ask patches with [ pxcor = -4 and pycor = -4 ] [ set pcolor 78 set name "Ticket payment" set duration-triang "2.5*3*3.5" set typeForm "AutomaticTask" set name-queue "Queue-TicketPayment"]
  ask patches with [ pxcor = -4  and pycor = -10 ] [ set pcolor 38 set name "Queue-Operation"  set typeForm "queue" set next-task-of-queue "Operation"]
  ask patches with [ pxcor = -12 and pycor = -10 ] [ set pcolor 97 set name "Operation" set duration-triang "2*4*6" set typeForm "HumanTask" set name-queue "Queue-Operation"] ; set duration-mean 900 set duration-devst 10

  ;; the exit/last form
  ask patches with [pxcor = -12 and pycor = 1] [set pcolor 8 set name "end" ]

  ;; initialize each task as "free"
  ask patches with [name != ""][ set pstate "free" ]

  ;; initialize empty queues
  ask patches with [name != "queue"][ set queue [] ]
end

to setup-labels
  ask patch -10 10 [ set plabel "Arrival customer" ]   ;; set labels on the screen
  ask patch 14 10 [ set plabel "Take number" ]
  ask patch 14 -8 [ set plabel "Registration" ]
  ask patch -2 -3 [ set plabel "Ticket payment" ]
  ask patch -11 -11 [ set plabel "Operation" ]
end


to setup-operators
  ;; create a certain number of operators having a shape of "person", a state "L", inizializing the duration variable
  create-operators n-of-operators [ setxy 0 3 set shape "person" set state "L" set work-durat-task 0 ]
end

to setup-monitors
  set monit-dismissed 0
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  PROCEDURE COMPUTINE THE FLOW  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report compute-next-task [ actual-task ]
  let nt nobody
  if actual-task = "Arrival customer" [set nt "Take number" ]
  if actual-task = "Take number" [set nt "Registration" ]
  if actual-task = "Registration" [
    ifelse random 100 < 70 [ set nt "Ticket payment" ]
    [ set nt "Operation" ]
  ]
  if actual-task = "Ticket payment" [ set nt "Operation" ]
  if actual-task = "Operation" [ set nt "end" ]
  report one-of patches with [name = nt]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      MAIN  CYCLE     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  tick                        ;; increasing time
  if ticks = 10000 [ stop ]   ;; stop condition
  arrival-tokens              ;; create new tokens
  move-agents                 ;;
  check-agent-in-queue        ;;
  start-automatic-tasks       ;; check if both operator and token are waiting on a (automatic) task: if yes, they start the service "S"
  start-human-tasks           ;; check if both operator and token are waiting on a (human) task: if yes, they start the service "S"
  operators-looking           ;;
  check-time
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; PROCEDURES IN THE MAIN CYCLE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to arrival-tokens
  if ticks mod 60 = 0 [;=  0 [   ; one token every 5 minutes  mod 300 = 10 [  ;
    crea-token
  ]
end

to crea-token
  create-tokens n-of-arrivals [
    set shape "dot"              ;; initialize variables
    set work-durat-task 0        ;;
    set arrival-time ticks       ;;

    move-to one-of patches with [ name = "Arrival customer" ]    ;; the new Token starts directly in the Arrival point

    set next-task one-of patches with [ name = "Take number" ]   ;; compute-next-task [name] of patch-here
    insert-in-queue self next-task           ;; add 'token' into the corresponding list (queue variable)

    set destination one-of patches with [ name = [name-queue] of  [next-task] of myself ] ;;
    set heading towards destination ;;
    set state "M"               ;;

    if trace-paths? [pd]        ;; to trace the paths of tokens during their movements
  ]
end

to insert-in-queue [ t a ]
  ask a [
    set queue lput t queue
  ]
end

to move-agents
  if any? turtles with [state = "M"] [
    ask turtles with [state = "M"] [
      fd 1                                    ;; forward 1
      if patch-here = destination [           ;; once arrived at destination...
        set state "W"                              ;; set 'state' at "W"
        if breed = tokens and [name] of next-task = "end" [  ;; at the end of the path
          update-dis                               ;; increment monitor dismission
          die                                      ;; elimiante the 'token'
        ]
      ]
    ]
  ]
end

to update-dis
  set monit-dismissed monit-dismissed + 1
end

;; PROCEDURE FOR AUTOMATIC TASKS
to check-agent-in-queue   ;; check agents in queue
  if any? patches with [ pstate = "free" and typeform = "AutomaticTask" and not empty? queue ]
  [ ask patches with [ pstate = "free" and typeform = "AutomaticTask" and not empty? queue ]
    [
      ask last queue   ;;; THE AGENT DECIDES TO MOVE "M" TOWARDS THE NEXT TASK
      [
        set state "M"
        set destination myself
        set heading towards destination
      ]
      set queue but-last queue
      set pstate "busy"
    ]
  ]
end

to start-automatic-tasks
  if any? tokens with [ state = "W" and  [typeform] of patch-here = "AutomaticTask" ][
    ask tokens with [ state = "W" and  [typeform] of patch-here = "AutomaticTask" ][
      set state "S"
      let duration compute-duration self
      set work-durat-task ticks + duration
    ]
  ]
end

to start-human-tasks
  if any? operators with [ state = "W" and [state] of work-with = "W" and [typeform] of patch-here = "HumanTask" ] [
  ask operators with [ state = "W" and [state] of work-with =  "W"  and [typeform] of patch-here = "HumanTask" ] ;[pcolor] of [patch-here] of work-with = 97 ]
    [
      set state "S"
      ask work-with [set state "S"]

      let duration compute-duration self
      set work-durat-task ticks + duration
    ]
  ]
end

to operators-looking
  if any? operators with [ state = "L" ] and any? patches with [ pstate = "free" and  typeForm = "HumanTask" and not empty? queue  ] [
    ; SELECT AN OPERATOR....  AL MOMENTO NE VIENE SCELTO UNO A CASO
    ask one-of operators with [ state = "L"] [

      ask one-of patches with [  pstate = "free" and typeForm = "HumanTask" and not empty? queue  ]
      [ ;SELECT THE LAST CUSTOMER/PATIENT TO WORK WITH
        let t last queue  ;

        ask t [
          set state "M"                   ;; set state "M"
          set destination myself
          set heading towards destination
        ]

        set queue but-last queue

        ask myself [
          set state "M"
          set destination myself
          set heading towards destination
          if destination = patch-here [set state "W"]
          set work-with t
        ]
        set pstate "busy"
      ]

    ]
  ]
end

to-report select-min-token [t]
  report min-one-of t [ arrival-time ]
end


to check-time
  if any? operators with [state = "S" and work-durat-task = ticks][
    ask operators with [state = "S" and work-durat-task = ticks][
      ask work-with [
        set state "M"
        ifelse [name] of next-task != "Operation" [
          set next-task compute-next-task [name] of next-task
          insert-in-queue self next-task

          set destination one-of patches with [ name = [name-queue] of  [next-task] of myself ]
          set heading towards destination
          fd 1
        ]
        [
          set next-task compute-next-task [name] of next-task
          set destination one-of patches with [name = "end"]
          set heading towards destination
        ]
      ]
      set state "L"
      set work-with nobody

      ask patch-here [set pstate "free"]
    ]
  ]

  ;; PROCEDURE TO CHECK ( AUTOMATIC TASKS )... non dovrebbe servire aggiungere questo : and  [typeform] of patch-here = "AutomaticTask" ]
  if any? tokens with [ state = "S" and work-durat-task = ticks ][ ; and [pcolor] of patch-here  = 78][
    ask tokens with [ state = "S" and work-durat-task = ticks ][ ; and [pcolor] of patch-here = 78][
      set state "M"
      ask patch-here [ set pstate "free" ]
      ifelse [name] of next-task != "Operation" [
        set next-task compute-next-task [name] of  next-task
        insert-in-queue self next-task               ; insert token into list of the  patch with name = ...

        set destination one-of patches with [ name = [name-queue] of  [next-task] of myself ]
        set heading towards destination
      ]
      [
        set next-task "end"
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;             UTILS            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report z-random-triangular [#a #b #c]
  if not (#a < #b and #b < #c) [error "Triangular Distribution parameters are in the wrong order"]

  let FC ((#b - #a) / (#c - #a))
  let U random-float 1
  ifelse U < FC [

    report (#a + (sqrt (U * (#c - #a) * (#b - #a))))
  ]
  [
    report (#c - (sqrt ((1 - U ) * (#c - #a) * (#c - #b))))
  ]
end

to-report compute-duration [a]
  let rep 0
  ifelse ([duration-triang] of a = "") [
    set rep int(random-normal [duration-mean] of patch-here [duration-devst] of patch-here)
  ]
  [
    let d [duration-triang] of a
    let triang-min substring d 0 position "*" d
    let altra-triang-min (substring d (position "*" d + 1) length (d))
    let triang-med substring altra-triang-min 0 position "*" altra-triang-min
    let triang-max (substring altra-triang-min (position "*" altra-triang-min + 1) length(altra-triang-min))
    set rep z-random-triangular read-from-string (triang-min) read-from-string triang-med read-from-string triang-max  ;round
  ]
  report round(rep)
end
@#$#@#$#@
GRAPHICS-WINDOW
231
10
734
394
-1
-1
15.0
1
12
1
1
1
0
0
0
1
-16
16
-12
12
0
0
1
ticks
30.0

BUTTON
67
179
134
235
SETUP
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
137
179
203
235
NIL
GO
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

MONITOR
753
58
853
103
NIL
monit-dismissed
17
1
11

SWITCH
72
117
198
150
trace-paths?
trace-paths?
0
1
-1000

SLIDER
50
46
222
79
n-of-operators
n-of-operators
1
10
1.0
1
1
NIL
HORIZONTAL

MONITOR
738
134
875
179
Queue of Take Number
length [queue] of one-of patches with [ name = \"Take number\"]
17
1
11

MONITOR
738
180
875
225
Queue of Registration
length [queue] of one-of patches with [ name = \"Registration\"]
17
1
11

MONITOR
738
272
875
317
Queue of Operation
length [queue] of one-of patches with [ name = \"Operation\"]
17
1
11

MONITOR
738
226
875
271
Queue of Ticket Payment
length [queue] of one-of patches with [ name = \"Ticket payment\"]
17
1
11

SLIDER
50
80
222
113
n-of-arrivals
n-of-arrivals
1
500
1.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

The model describes the functioning of a Service with four activities: two of the have an operator, the other two are performed by customers (i.e., tokens).

Operators and tokens are the agents in our model.



## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

Agents use 

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
