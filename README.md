# SonoVision

Locating objects for the visually impaired is a significant challenge and is something no one can get used to over time. However, this hinders their independence and could push them towards risky and dangerous scenarios. Hence, in the spirit of making the visually challenged more self-sufficient, we present SonoVision, a smart-phone application that helps them find everyday objects using sound cues through earphones/headphones. This simply means, if an object is on the right or left side of a user, the app makes a sinusoidal sound in a user's respective ear through ear/headphones. However, to indicate objects located directly in front, both the left and right earphones are rung simultaneously. These sound cues could easily help a visually impaired individual locate objects with the help of their smartphones and reduce the reliance on people in their surroundings, consequently making them more independent. This application is made with the flutter development platform and uses the Efficientdet-D2 model for object detection in the backend. We believe the app will significantly assist the visually impaired in a safe and user-friendly manner with its capacity to work completely offline.

## Working Principle

<div style="display: flex; justify-content: space-around; align-items: center; width: 100%;">
  <img src="https://github.com/MohammedZ666/SonoVision/blob/main/cup_left_em.png" alt="Left cup" width="30%"/>
  <img src="https://github.com/MohammedZ666/SonoVision/blob/main/cup_center_em.png" alt="Center cup" width="30%"/>
  <img src="https://github.com/MohammedZ666/SonoVision/blob/main/cup_right_em.png" alt="Right cup" width="30%"/>
</div>

The figures above shows the working principle of our application, indicating the position of an Object of Interest (cup) on left, center, and, right through sound cues in the left, both, and right ears respectivly through ear/phones (as indicated by 🔊). 

## Setup (Android only)

Follow these steps to build and run the project locally:

### Prerequisites
- [Insall Flutter](https://docs.flutter.dev/get-started/install)
- [Install a compatible IDE](https://docs.flutter.dev/get-started/install/windows/mobile#configure-a-text-editor-or-ide)
- A physical device or emulator/simulator

### Installation
Run the following commands in your IDE's terminal to download and run the project:
 ```bash
# clone repo 
git clone https://github.com/MohammedZ666/SonoVision.git
cd SonoVision
# get dependencies
flutter pub get
# run the app
flutter run
```
## TODO Checklist

- [x] ~Sound cue detection functionality based on EfficientDet-D2~
- [ ] Sound cue based object relocation through open-set detectors
- [ ] Building and testing on iOS
- [ ] Releasing for Google Play Store and App Store

## Contribution
To contribute, create an [create an issue](../../issues) and then open a PR with your proposed fix.

## Funding
This project was funded by BRACU University's Research Seed Grant Initiative for the `AI Powered Enhancement fof University Life Accessibility for Blind People`. 
      
