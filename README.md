# AIO Data Distribution Service (DDS) Connector

This repo provides the DSS messaging protocol connector for Azure IoT Operations (AIO) product. The protocol is often used on both general public vehicles or armoured vehicles in sensitive settings, for a real-time messaging.

The repo makes use of Akri framework and AIO SDKs for building the connector which is well integrated with AIO's ecosystem of services e.g. asset model.

## DDS Key Points

This section describes some of the key DDS points for connectivity purposes.

### Data Centric Pub Sub (DCPS)

OMG IDL which defines topics must be translated into code for message serialization and deserialization by publisher and subscriber. An example IDL file is provided below for reference:

```IDL
module Messenger {

  @topic
  struct Message {
    string from;
    string subject;
    @key long subject_id;
    string text;
    long count;
  };
};
```

`Key` defines the DDS instance within the same topic, each message sample with the same key is considered as a replacement value.

## General Questions for Connector Adoption

1. Does the server make use of DCPS for messaging?
2. Does the server makes use of OMG Interface Definition Language (IDL) for messaging?

## References

1. [Open DDS](https://opendds.readthedocs.io/)
2. [Atostek RustDDS](https://github.com/Atostek/RustDDS)
3. OpenDDSSharp:
    1. [OpenDDSSharp](https://www.openddsharp.com/)
    2. [OpenDDSSharp Example](https://objectcomputing.com/resources/publications/sett/october-2020-opendds-in-a-net-application-with-openddsharp)
