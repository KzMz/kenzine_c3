module kenzine::event;

import kenzine::core;
import kenzine::faults;

fault EventError
{
    LISTENER_ALREADY_SUBSCRIBED,
}

struct EventData
{
    char[16] data;
}

enum SystemEventCode : int
{
    APPLICATION_QUIT,
    KEY_PRESSED,
    KEY_RELEASED,
    BUTTON_PRESSED,
    BUTTON_RELEASED,
    MOUSE_MOVED,
    MOUSE_WHEEL,
    WINDOW_RESIZED,
    SET_RENDER_MODE,
    HID_DEVICE_CONNECTED,
    HID_DEVICE_DISCONNECTED,
}

def EventCallback = fn bool!(uint, void*, void*, EventData);

struct EventParams
{
    void* p;
}

struct EventSubscription
{
    void* listener;
    EventCallback callback;
}

struct EventEntry
{
    EventSubscription[16] subscriptions;
}

struct EventState
{
    EventEntry[256] entries;
}

struct EventSystem(kenzine::core::System(<EventState, EventParams>))
{
    EventState* state;
}

EventState* event_state = null;

fn void! EventSystem.initialize(EventSystem* self, EventState* state, EventParams* params) @dynamic
{
    self.state = state;
    event_state = self.state;

    if (self.state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    if (params == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }
}

fn void! EventSystem.shutdown(EventSystem* self) @dynamic
{
    for (int i = 0; i < self.state.entries.len; i++)
    {
        for (int j = 0; j < self.state.entries[j].subscriptions.len; j++)
        {
            self.state.entries[i].subscriptions[j].listener = null;
            self.state.entries[i].subscriptions[j].callback = null;
        }
    }
}

fn int EventSystem.get_state_size(EventSystem* self) @dynamic
{
    return EventState.sizeof;
}

fn void! subscribe(int code, void* listener, EventCallback callback)
{
    if (event_state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    EventEntry* entry = &event_state.entries[code];
    for (int i = 0; i < entry.subscriptions.len; i++)
    {
        if (entry.subscriptions[i].listener == listener)
        {
            return EventError.LISTENER_ALREADY_SUBSCRIBED?;
        }

        if (entry.subscriptions[i].listener == null)
        {
            entry.subscriptions[i].listener = listener;
            entry.subscriptions[i].callback = callback;
            break;
        }
    }
}

fn void! EventSystem.subscribe(EventSystem* self, int code, void* listener, EventCallback callback) @dynamic
{
    subscribe(code, listener, callback)!;
}

fn void! unsubscribe(int code, void* listener)
{
    if (event_state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    EventEntry* entry = &event_state.entries[code];
    for (int i = 0; i < entry.subscriptions.len; i++)
    {
        if (entry.subscriptions[i].listener == listener)
        {
            entry.subscriptions[i].listener = null;
            entry.subscriptions[i].callback = null;
            break;
        }
    }
}

fn void! EventSystem.unsubscribe(EventSystem* self, int code, void* listener) @dynamic
{
    unsubscribe(code, listener)!;
}

fn void! trigger(int code, void* sender, EventData event_data)
{
    if (event_state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    EventEntry* entry = &event_state.entries[code];
    for (int i = 0; i < entry.subscriptions.len; i++)
    {
        if (entry.subscriptions[i].listener != null)
        {
            void* listener = entry.subscriptions[i].listener;
            entry.subscriptions[i].callback(code, sender, listener, event_data)!;
        }
    }
}

fn void! EventSystem.trigger(EventSystem* self, int code, void* sender, EventData event_data) @dynamic
{
    trigger(code, sender, event_data)!;
}