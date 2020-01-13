#cython: language_level=3

cdef extern from "ladspa.h":
    ctypedef float LADSPA_Data
    ctypedef int LADSPA_Properties

    int LADSPA_PROPERTY_REALTIME
    int LADSPA_PROPERTY_INPLACE_BROKEN
    int LADSPA_PROPERTY_HARD_RT_CAPABLE

    void LADSPA_IS_REALTIME(int x) 
    void LADSPA_IS_INPLACE_BROKEN(int x)
    void LADSPA_IS_HARD_RT_CAPABLE(int x)

    ctypedef int LADSPA_PortDescriptor

    int LADSPA_PORT_INPUT 
    int LADSPA_PORT_OUTPUT
    int LADSPA_PORT_CONTROL
    int LADSPA_PORT_AUDIO 

    void LADSPA_IS_PORT_INPUT(int x)
    void LADSPA_IS_PORT_OUTPUT(int x)
    void LADSPA_IS_PORT_CONTROL(int x)
    void LADSPA_IS_PORT_AUDIO(int x)

    ctypedef int LADSPA_PortRangeHintDescriptor

    int LADSPA_HINT_BOUNDED_BELOW 
    int LADSPA_HINT_BOUNDED_ABOVE 
    int LADSPA_HINT_TOGGLED    
    int LADSPA_HINT_SAMPLE_RATE 
    int LADSPA_HINT_LOGARITHMIC 
    int LADSPA_HINT_INTEGER      
    int LADSPA_HINT_DEFAULT_MASK  
    int LADSPA_HINT_DEFAULT_NONE   
    int LADSPA_HINT_DEFAULT_MINIMUM 
    int LADSPA_HINT_DEFAULT_LOW  
    int LADSPA_HINT_DEFAULT_MIDDLE
    int LADSPA_HINT_DEFAULT_HIGH 
    int LADSPA_HINT_DEFAULT_MAXIMUM
    int LADSPA_HINT_DEFAULT_0
    int LADSPA_HINT_DEFAULT_1 
    int LADSPA_HINT_DEFAULT_100
    int LADSPA_HINT_DEFAULT_440 

    void LADSPA_IS_HINT_BOUNDED_BELOW(int x) 
    void LADSPA_IS_HINT_BOUNDED_ABOVE(int x)
    void LADSPA_IS_HINT_TOGGLED(int x)    
    void LADSPA_IS_HINT_SAMPLE_RATE(int x)
    void LADSPA_IS_HINT_LOGARITHMIC(int x) 
    void LADSPA_IS_HINT_INTEGER(int x)   

    void LADSPA_IS_HINT_HAS_DEFAULT(int x) 
    void LADSPA_IS_HINT_DEFAULT_MINIMUM(int x)
    void LADSPA_IS_HINT_DEFAULT_LOW(int x)   
    void LADSPA_IS_HINT_DEFAULT_MIDDLE(int x)
    void LADSPA_IS_HINT_DEFAULT_HIGH(int x) 
    void LADSPA_IS_HINT_DEFAULT_MAXIMUM(int x)
    void LADSPA_IS_HINT_DEFAULT_0(int x)     
    void LADSPA_IS_HINT_DEFAULT_1(int x)    
    void LADSPA_IS_HINT_DEFAULT_100(int x) 
    void LADSPA_IS_HINT_DEFAULT_440(int x)

    
    cdef struct _LADSPA_PortRangeHint:
        LADSPA_PortRangeHintDescriptor HintDescriptor
        LADSPA_Data LowerBound
        LADSPA_Data UpperBound
    ctypedef _LADSPA_PortRangeHint LADSPA_PortRangeHint

    ctypedef void* LADSPA_Handle

    cdef struct _LADSPA_Descriptor:
        unsigned long UniqueID
        const char* Label
        LADSPA_Properties Properties
        const char* Name
        const char* Maker
        const char* Copyright
        unsigned long PortCount
        const LADSPA_PortDescriptor* PortDescriptors
        const char* const* PortNames
        const LADSPA_PortRangeHint* PortRangeHints
        void* ImplementationData

        LADSPA_Handle (*instantiate)(const _LADSPA_Descriptor* Descriptor, unsigned long SampleRate)

        void (*connect_port)(LADSPA_Handle Instance, unsigned long Port, LADSPA_Data* DataLocation)
        void (*activate)(LADSPA_Handle Instance)
        void (*run)(LADSPA_Handle Instance, unsigned long SampleCount)
        void (*run_adding)(LADSPA_Handle Instance, unsigned long SampleCount)
        void (*set_run_adding_gain)(LADSPA_Handle Instance, LADSPA_Data Gain)
        void (*deactivate)(LADSPA_Handle Instance)
        void (*cleanup)(LADSPA_Handle Instance)
    ctypedef _LADSPA_Descriptor LADSPA_Descriptor

    const LADSPA_Descriptor* ladspa_descriptor(unsigned long Index)
    ctypedef const LADSPA_Descriptor* (*LADSPA_Descriptor_Function)(unsigned long Index)


