libTimer
========

This is a simple timer implentation for Rift addons to use.

As jnwhiteh have pointed out, this is not the most optimum way of doing it,
but it is simple, and it is also pretty fast. 

The main problems will be with extremely many and/or very small repeating timers,
as it has to update the timers index every time a timer is added or removed.

Commands
========
(params marked with * are optional)

timer_reference = StartTimer(seconds, callback, data*, repeating*)

	Creates a timer, which will run when "seconds" value of time has passed.

	seconds   -- Seconds until the timer is run. Can be fractional numbers.
	callback  -- The callback function to run when the timer is up
	data      -- (Optional) Data to send to the callback
	repeating -- (Optional) If the timer shall be repeating
	
	Function returns a reference to the timer created
	
StopTimer(timer_reference)
	
	Will stop an existing timer.
	
	timer_reference -- The reference of the timer you want to stop
	
libTimer_SetDebug(int)
	
	Will set the level of debug messages that will be shown.
	
	int -- Value from 0 to 10. 0 means no messages (default), 10 means a lot of messages.
	
	
Examples
========

Very basic example
-------------------------
|	function myFunc()
|		print("This is a delayed function")
|	end
|
|	StartTimer(10, myFunc)
-------------------------


Sending data to callback
-------------------------
|	function myFunc(v)
|		print("This function was called with "..v)
|	end
|
|	StartTimer(10, myFunc, "The Power of Time!")
-------------------------

Repeating timer
-------------------------
|	function myFunc()
|		print("I rise! ..again")
|	end
|
|	wicked = StartTimer(10, myFunc, nil, 1)
-------------------------

Stop that repeating timer
-------------------------
|	StopTimer(wicked)
-------------------------

A bit more complex stuff
-------------------------
|	i = 0
|	function myFunc()
|		i = i + 1
|		print(i.." Some dummy thing happening")
|	end
|
|	wicked = StartTimer(2, myFunc, nil, 1)
|
|	StartTimer(12, function (v) StopTimer(v) print("Begone foul fiend!") end, wicked)
-------------------------